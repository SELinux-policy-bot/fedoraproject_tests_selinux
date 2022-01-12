#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-userdbd-and-similar
#   Description: SELinux interferes with systemd-userdbd and related programs
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/lib/systemd/systemd-userdbd"
FILE_CONTEXT="systemd_userdbd_exec_t"
SERVICE_PACKAGE="systemd"
SERVICE_NAME="systemd-userdbd"
PROCESS_NAME="systemd-userdbd"
PROCESS_CONTEXT="systemd_userdbd_t"
ALLOWED_USERS=${ALLOWED_USERS:-"staff_u user_u guest_u xguest_u sysadm_u unconfined_u"}
DENIED_USERS=${DENIED_USERS:-""}

rlJournalStart
    if [ ! -f /usr/lib/systemd/systemd-userdbd ] ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

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
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#1835630"
        rlSEMatchPathCon "/run/systemd/userdb/io.systemd.Multiplexer" "systemd_userdbd_runtime_t"
        rlSESearchRule "allow guest_t systemd_userdbd_runtime_t : sock_file { write } [ ]"
        rlSESearchRule "allow xguest_t systemd_userdbd_runtime_t : sock_file { write } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- confined users"
        rlSEConfigureSSH

        rlRun "setsebool ssh_sysadm_login on"
        rlRun "setsebool selinuxuser_tcp_server on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -Rv /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost userdbctl user"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost userdbctl group"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost userdbctl services"
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool selinuxuser_tcp_server off"
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- ${SERVICE_NAME}.socket"
        rlRun "systemctl stop systemd-userdbd.socket"
        rlRun "systemctl status systemd-userdbd.socket" 3
        rlRun "systemctl start systemd-userdbd.socket"
        rlRun "systemctl status systemd-userdbd.socket"
        rlRun "ls -dZ /run/systemd/userdb | grep :systemd_userdbd_runtime_t"
        rlRun "ls -Z /run/systemd/userdb/io.systemd.Multiplexer | grep :systemd_userdbd_runtime_t"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
        rlRun "service sshd restart"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

