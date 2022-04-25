#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/boltd-and-similar
#   Description: SELinux interferes with boltd and related programs
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
FILE_PATH="/usr/libexec/boltd"
FILE_CONTEXT="boltd_exec_t"
SERVICE_PACKAGE="bolt"
SERVICE_NAME="bolt"
PROCESS_NAME="boltd"
PROCESS_CONTEXT="boltd_t"
ALLOWED_USERS="staff_u user_u xguest_u sysadm_u unconfined_u"
DENIED_USERS="guest_u"

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

    rlPhaseStartTest "bz#1589086 + bz#1684103 + bz#1685591"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/var/lib/boltd" "boltd_var_lib_t"
        rlSEMatchPathCon "/var/run/dbus" "system_dbusd_var_run_t"
        rlSEMatchPathCon "/var/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSEMatchPathCon "/var/lib/sss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/mc" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/mc/passwd" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/pipes" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSEMatchPathCon "/run/udev" "udev_var_run_t"
        rlSEMatchPathCon "/run/udev/control" "udev_var_run_t"
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
        rlSESearchRule "allow unconfined_t boltd_t : dbus { send_msg }"
        rlSESearchRule "allow boltd_t unconfined_t : dbus { send_msg }"
        rlSESearchRule "allow boltd_t sssd_public_t : dir { search }"
        rlSESearchRule "allow boltd_t sssd_public_t : file { getattr map open read }"
        rlSESearchRule "allow boltd_t sssd_var_lib_t : sock_file { write }"
        rlSESearchRule "allow boltd_t udev_var_run_t : dir { search }"
        rlSESearchRule "allow boltd_t system_dbusd_var_run_t : dir { search }"
        rlSESearchRule "allow boltd_t system_dbusd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow boltd_t system_dbusd_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1625786"
        rlSESearchRule "allow boltd_t policykit_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow policykit_t boltd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow boltd_t system_dbusd_t : dbus { acquire_svc } [ ]"
        rlSESearchRule "allow boltd_t xdm_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow xdm_t boltd_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1702243 + bz#1704766"
        rlSESearchRule "allow staff_t boltd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow boltd_t staff_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow user_t boltd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow boltd_t user_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow xguest_t boltd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow boltd_t xguest_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- system D-bus"
        DESTINATION="org.freedesktop.bolt"
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 2
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
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

    rlPhaseStartTest "real scenario -- confined users"
        rlSEConfigureSSH

        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost boltctl list"
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

