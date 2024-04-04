#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/dmidecode-and-similar
#   Description: SELinux interferes with dmidecode and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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
ALLOWED_USERS=${ALLOWED_USERS:-"sysadm_u unconfined_u"}
DENIED_USERS=${DENIED_USERS:-"staff_u user_u guest_u xguest_u"}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm dmidecode

        rlSEConfigureSSH

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#263141"
        rlSEMatchPathCon "/usr/sbin/dmidecode" "dmidecode_exec_t"
        rlSESearchRule "allow dmidecode_t sysfs_t : dir { getattr open search } [ ]"
        rlSESearchRule "allow dmidecode_t sysfs_t : file { getattr open read } [ ]"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1289274"
        rlSEMatchPathCon "/usr/sbin/dmidecode" "dmidecode_exec_t"
        rlSEMatchPathCon "/dev/urandom" "urandom_device_t"
        rlSESearchRule "allow dmidecode_t urandom_device_t : chr_file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1300799"
        rlSEMatchPathCon "/usr/sbin/dmidecode" "dmidecode_exec_t"
        rlSEMatchPathCon "/run/lock/subsys/rhsmcertd" "rhsmcertd_lock_t"
        rlSEMatchPathCon "/var/log/rhsm/rhsm.log" "rhsmcertd_log_t"
        rlSESearchRule "allow dmidecode_t rhsmcertd_lock_t : file { open }"
        rlSESearchRule "allow dmidecode_t rhsmcertd_log_t : file { open read }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1608480"
        rlSEMatchPathCon "/usr/sbin/dmidecode" "dmidecode_exec_t"
        rlSESearchRule "allow rhsmcertd_t dmidecode_exec_t : file { map } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- runcon"
        # this TC does not belong to the small set of SELinux domains which can run dmidecode in the system_u:system_r:dmidecode_t:s0 context, therefore we need some help
        # TODO: use sysadm_t user instead of initrc_t to run dmidecode, because sysadm_t is allowed to transition to dmidecode_t
        rlRun "ls -l testpolicy.*"
        rlRun "make -f /usr/share/selinux/devel/Makefile testpolicy.pp"
        rlRun "semodule -i testpolicy.pp"

        rlRun "runcon system_u:system_r:initrc_t:s0 bash -c /usr/sbin/dmidecode"
        if [ -f /usr/sbin/biosdecode ] ; then
            rlRun "runcon system_u:system_r:initrc_t:s0 bash -c /usr/sbin/biosdecode"
        fi
        if [ -f /usr/sbin/vpddecode ] ; then
            rlRun "runcon system_u:system_r:initrc_t:s0 bash -c /usr/sbin/vpddecode"
        fi
        if [ -f /usr/sbin/ownership ] ; then
            rlRun "runcon system_u:system_r:initrc_t:s0 bash -c /usr/sbin/ownership"
        fi

        rlRun "semodule -l | grep testpolicy"
        rlRun "semodule -r testpolicy"
        rlRun "semodule -l | grep testpolicy" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- confined users"
        CREATED_USERS=""
        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -o -u 0 -g 0 -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            if [ -f /usr/sbin/dmidecode ] ; then
                rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/dmidecode"
            fi
            if [ -f /usr/sbin/biosdecode ] ; then
                rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/biosdecode"
            fi
            if [ -f /usr/sbin/vpddecode ] ; then
                rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/vpddecode"
            fi
            if [ -f /usr/sbin/ownership ] ; then
                rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/ownership"
            fi
            sleep 2
            CREATED_USERS="${USER_NAME} ${CREATED_USERS}"
        done
        rlRun "setsebool ssh_sysadm_login off"
        for USER_NAME in ${CREATED_USERS} ; do
            rlRun "userdel -rfZ ${USER_NAME}"
        done
    rlPhaseEnd

    rlPhaseStartTest "RHEL-16104"
        rlSEMatchPathCon "/var" "var_t"
        rlSEMatchPathCon "/var/log" "var_log_t"
        rlSEMatchPathCon "/var/log/sudo-io" "sudo_log_t"
        rlSESearchRule "allow sysadm_sudo_t var_t : dir { read } [ ]"
        rlSESearchRule "allow sysadm_sudo_t var_log_t : dir { read } [ ]"
        rlSESearchRule "allow sysadm_sudo_t sudo_log_t : dir { read } [ ]"
        rlRun "setsebool ssh_sysadm_login on"
        rlRun "useradd -Z sysadm_u -G wheel sysadm-user"
        USER_SECRET="S3kr3t${RANDOM}"
        rlRun "echo ${USER_SECRET} | passwd --stdin sysadm-user"
        rlRun "echo -en 'Defaults log_output\nDefaults log_input\nDefaults iolog_dir=/var/log/sudo-io\nsysadm-user ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/sysadm-user"
        rlRun "rm -rf /var/log/sudo-io"
        rlRun -s "./ssh.exp sysadm-user ${USER_SECRET} localhost sudo dmidecode"
        rlRun "grep DMI $rlRun_LOG"
        rlRun "rm -f $rlRun_LOG"
        rlRun "rm -rf /var/log/sudo-io"
        rlRun -s "./ssh.exp sysadm-user ${USER_SECRET} localhost sudo -r sysadm_r dmidecode"
        rlRun "grep DMI $rlRun_LOG"
        rlRun "rm -f $rlRun_LOG"
        rlRun "rm -f /etc/sudoers.d/sysadm-user"
        rlRun "userdel -rfZ sysadm-user"
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

