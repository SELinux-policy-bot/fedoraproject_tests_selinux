#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/colord-and-similar
#   Description: SELinux interferes with colord and related programs
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
SERVICE_PACKAGE="colord"
SERVICE_NAME="colord"
PROCESS_NAME="colord"
PROCESS_CONTEXT="colord_t"
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

    rlPhaseStartTest "bz#1373082 + bz#1381579 + bz#1398030 + bz#1421247 + bz#1460480"
        rlSEMatchPathCon "/usr/libexec/colord" "colord_exec_t"
        rlSEMatchPathCon "/etc/udev/hwdb.bin" "systemd_hwdb_etc_t"
        rlSESearchRule "allow colord_t systemd_hwdb_etc_t : file { getattr open read } [ ]"
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "real scenario -- DBus service"
        DESTINATION="org.freedesktop.ColorManager"
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "real scenario -- user session service"
        rlSEConfigureSSH

        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/bin/systemctl --user --no-pager status colord-session"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/bin/systemctl --user --no-pager start colord-session"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/bin/systemctl --user --no-pager stop colord-session"
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartTest "bz#1772669"
    # TODO: find an agreement about which confined users should be allowed
        rlSESearchRule "allow staff_t colord_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow colord_t staff_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow user_t colord_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow colord_t user_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow sysadm_t colord_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow colord_t sysadm_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow unconfined_t colord_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow colord_t unconfined_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#1772669"
        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost colormgr get-devices"
            sleep 2
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
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

