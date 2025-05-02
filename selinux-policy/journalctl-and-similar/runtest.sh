#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/journalctl-and-similar
#   Description: SELinux interferes with journalctl executed by various users
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
FILE_PATH="/usr/bin/journalctl"
FILE_CONTEXT="journalctl_exec_t"
SERVICE_PACKAGE="systemd"
PROCESS_NAME="journalctl"
PROCESS_CONTEXT="journalctl_t"
ALLOWED_USERS=${ALLOWED_USERS:-"staff_u user_u sysadm_u unconfined_u"}
DENIED_USERS=${DENIED_USERS:-"guest_u xguest_u"}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlSEConfigureSSH

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1176713"
        rlSEMatchPathCon "/usr/bin/journalctl" "journalctl_exec_t"
        rlSEMatchPathCon "/dev/urandom" "urandom_device_t"
        rlSESearchRule "allow journalctl_t urandom_device_t : chr_file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1288255"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow staff_t ${FILE_CONTEXT} : file { getattr open read execute } [ ]"
        rlSESearchRule "allow sysadm_t ${FILE_CONTEXT} : file { getattr open read execute } [ ]"
        rlSESearchRule "allow user_t ${FILE_CONTEXT} : file { getattr open read execute } [ ]"
        rlSESearchRule "allow staff_t ${PROCESS_CONTEXT} : process { transition } [ ]"
        rlSESearchRule "allow sysadm_t ${PROCESS_CONTEXT} : process { transition } [ ]"
        rlSESearchRule "allow user_t ${PROCESS_CONTEXT} : process { transition } [ ]"
        rlSESearchRule "type_transition staff_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} [ ]"
        rlSESearchRule "type_transition sysadm_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} [ ]"
        rlSESearchRule "type_transition user_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1685689"
        rlSEMatchPathCon "/usr/bin/journalctl" "journalctl_exec_t"
        rlSEMatchPathCon "/run/log/journal/bfd37efc55db4f44a0f350821db2b810/system.journal" "syslogd_var_run_t"
        if rlIsRHEL 7 ; then
            # the domain_can_mmap_files boolean is enabled by default
            rlSESearchRule "allow journalctl_t syslogd_var_run_t : file { map }"
        else
            # the domain_can_mmap_files boolean is disabled by default
            rlSESearchRule "allow journalctl_t syslogd_var_run_t : file { map } [ ]"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#1825894"
        rlSEMatchPathCon "/usr/bin/journalctl" "journalctl_exec_t"
        rlSESearchRule "allow journalctl_t journalctl_t : process { setrlimit } [ ]"
    rlPhaseEnd

    if ! rlIsFedora ; then
    rlPhaseStartTest "bz#2017838"
        rlSEMatchPathCon "/run/log/journal/somehash/system.journal" "syslogd_var_run_t"
        rlSEMatchPathCon "/var/lib/systemd/catalog/database" "init_var_lib_t"
        rlSESearchRule "allow user_t init_var_lib_t : file { open read map } [ ]"
        rlSESearchRule "allow user_t syslogd_var_run_t : file { open read map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 7 8 && ! rlIsCentOS 7 8 ; then
    rlPhaseStartTest "bz#2075527 + bz#2152823"
        rlSESearchRule "allow syslogd_t syslogd_var_run_t : file { relabelfrom relabelto } [ ]"
        rlRun "journalctl --rotate"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- confined users"
        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "usermod -G systemd-journal ${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost journalctl -n 10 --no-pager --user"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost journalctl -n 10 --no-pager --system"
            USER_ID=`id -u ${USER_NAME}`
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost systemctl status user@${USER_ID}"
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    if ! ( IrIsRHEL 8 && rlIsRHEL "<8.8" ) && ! ( rlIsRHEL 9 && rlIsRHEL "<9.3" ); then
    rlPhaseStartTest "bz#2136189 + bz#2153782"
        rlSESearchRule "allow journalctl_t journalctl_t : capability { sys_resource } [ ]"
        rlSESearchRule "allow journalctl_t journalctl_t : process { setrlimit } [ ]"

        rlRun "setsebool ssh_sysadm_login on"
        USER_NAME="toor"
        USER_SECRET="S3kr3t${RANDOM}"
        rlRun "useradd -o -u 0 -g 0 -Z sysadm_u ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost journalctl -l --no-pager"
        rlRun "userdel -rfZ ${USER_NAME}"
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC --ignore 'type=AVC .* create .*systemd.* scontext=.*:user_t:.* tcontext=.*:user_tmp_t:.* tclass=dir'
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

