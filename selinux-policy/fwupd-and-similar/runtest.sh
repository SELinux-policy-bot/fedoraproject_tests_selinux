#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/fwupd-and-similar
#   Description: SELinux interferes with fwupd and related programs.
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
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/libexec/fwupd/fwupd"
FILE_CONTEXT="fwupd_exec_t"
SERVICE_PACKAGE="fwupd"
SERVICE_NAME="fwupd"
PROCESS_NAME="fwupd"
PROCESS_CONTEXT="fwupd_t"
ALLOWED_USERS=${ALLOWED_USERS:-"staff_u user_u sysadm_u unconfined_u"}
DENIED_USERS=${DENIED_USERS:-"guest_u xguest_u"}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined ${PROCESS_CONTEXT} ; then
    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "real scenario -- DBus service"
        DESTINATION="org.freedesktop.fwupd"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # RHEL-4, RHEL-5, RHEL-6 is excluded
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # RHEL-4, RHEL-5, RHEL-6 is excluded
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    if rlSEDefined "fwupd_t" ; then
    rlPhaseStartTest "bz#1772619"
    # TODO: find an agreement about which confined users should be allowed
        rlSESearchRule "allow staff_t fwupd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow fwupd_t staff_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow user_t fwupd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow fwupd_t user_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow sysadm_t fwupd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow fwupd_t sysadm_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow unconfined_t fwupd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow fwupd_t unconfined_t : dbus { send_msg } [ ]"
    rlPhaseEnd
    fi

    if rlSEDefined "fwupd_var_lib_t" ; then
    rlPhaseStartTest "bz#1832231"
        rlSEMatchPathCon "/var/lib/fwupd" "fwupd_var_lib_t"
        rlSESearchRule "allow init_t fwupd_var_lib_t : dir { setattr } [ init_create_dirs ]"
    rlPhaseEnd
    fi

    if rlSEDefined "fwupd_cache_t" ; then
    rlPhaseStartTest "bz#1832234"
        rlSEMatchPathCon "/var/cache/fwupd" "fwupd_cache_t"
        rlSEMatchPathCon "/var/cache/fwupd/motd.d" "fwupd_cache_t"
        rlSEMatchPathCon "/var/cache/fwupd/motd.d/85-fwupd" "fwupd_cache_t"
        rlSESearchRule "allow init_t pam_var_run_t : dir { mounton } [ init_create_dirs ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1851932"
        rlSESearchRule "allow systemd_logind_t fwupd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow fwupd_t systemd_logind_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1832772"
        rlSEMatchPathCon "/dev/shm/lldpad.state" "lldpad_tmpfs_t"
        rlSESearchRule "allow init_t lldpad_tmpfs_t : file { getattr } [ ]"
        rlSESearchRule "allow init_t squid_tmpfs_t : file { getattr } [ ]"
        rlSESearchRule "allow init_t vhostmd_tmpfs_t : file { getattr } [ ]"
        rlSESearchRule "allow init_t wdmd_tmpfs_t : file { getattr } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#1832772"
        rlRun "ls -Z /dev/shm"
        rlRun "service fwupd-refresh start" 0-255
        sleep 1
        rlRun "service fwupd-refresh status" 0-255
        sleep 1
        rlRun "service fwupd-refresh stop" 0-255
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- confined users -- bz#1772619"
        rlSEConfigureSSH

        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost fwupdmgr get-devices"
            sleep 2
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlRun "service sshd restart"
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

