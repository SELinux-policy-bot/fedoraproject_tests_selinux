#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/policykit-general
#   Description: Test for BZ#962791 (SELinux is preventing /usr/lib/polkit-1/polkitd)
#   Author: Michal Trunecka <mtruneck@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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
SERVICE_NAME="polkit"
SERVICE_PACKAGE="polkit"
PROCESS_NAME="polkitd"
PROCESS_CONTEXT="policykit_t"
if rlIsRHEL 6 7 ; then
    ALLOWED_USERS="staff_u user_u xguest_u sysadm_u unconfined_u"
else
    ALLOWED_USERS="staff_u user_u guest_u xguest_u sysadm_u unconfined_u"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow
        rlSEConfigureSSH

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#960669 + bz#962791 + bz#965143"
        if rlIsRHEL 6 ; then
            rlSEMatchPathCon "/usr/libexec/polkit-1/polkitd" "policykit_exec_t"
        else
            rlSEMatchPathCon "/usr/lib/polkit-1/polkitd" "policykit_exec_t"
            rlSESearchRule "allow policykit_t cgroup_t : dir { open read getattr lock search ioctl }"
        fi
        rlSESearchRule "allow initrc_t policykit_exec_t : file { getattr open read execute }"
        rlSESearchRule "type_transition initrc_t policykit_exec_t : process policykit_t"
        rlSESearchRule "allow initrc_t policykit_t : process { transition }"
        rlSESearchRule "allow system_dbusd_t policykit_exec_t : file { getattr open read execute }"
        rlSESearchRule "type_transition system_dbusd_t policykit_exec_t : process policykit_t"
        rlSESearchRule "allow system_dbusd_t policykit_t : process { transition }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1003799"
        if rlIsRHEL 6 ; then
            rlSEMatchPathCon "/usr/libexec/polkit-1/polkitd" "policykit_exec_t"
        else
            rlSEMatchPathCon "/usr/lib/polkit-1/polkitd" "policykit_exec_t"
        fi
        rlSEMatchPathCon "/var/lib/sss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/mc" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/mc/passwd" "sssd_public_t"
        rlSESearchRule "allow policykit_t sssd_var_lib_t : dir { getattr open search }"
        rlSESearchRule "allow policykit_t sssd_public_t : dir { getattr open search }"
        rlSESearchRule "allow policykit_t sssd_public_t : file { getattr open read }"
        rlSESearchRule "allow policykit_t sssd_var_lib_t : sock_file { getattr open write }"
        rlSESearchRule "allow policykit_t sssd_t : unix_stream_socket { connectto }"
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#1301561"
        rlSEMatchPathCon "/usr/libexec/polkit-1/polkitd" "policykit_exec_t"
        rlSESearchRule "allow policykit_t fs_t : filesystem { getattr }"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- DBus service"
        rlRun "killall polkitd" 0,1
        sleep 1
        DESTINATION="org.freedesktop.PolicyKit1"
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1364513"
        rlSESearchRule "allow dhcpc_t policykit_t : dbus { send_msg }"
        rlSESearchRule "allow policykit_t dhcpc_t : dbus { send_msg }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1574389 + bz#1583082"
        rlSEMatchPathCon "/usr/bin/pkla-check-authorization" "policykit_auth_exec_t"
        rlSESearchRule "allow policykit_t policykit_auth_exec_t : file { map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1727902"
        rlSEMatchPathCon "/run/dbus" "system_dbusd_var_run_t"
        rlSEMatchPathCon "/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSESearchRule "allow guest_t system_dbusd_var_run_t : dir { search } [ ]"
        rlSESearchRule "allow guest_t system_dbusd_var_run_t : sock_file { write } [ ]"
        rlSESearchRule "allow guest_t system_dbusd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow guest_t policykit_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow policykit_t guest_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow guest_t system_dbusd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow system_dbusd_t guest_t : dbus { send_msg } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
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
        rlRun "restorecon -Rv /var /run -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- confined users"
        CREATED_USERS=""
        rlRun "setsebool ssh_sysadm_login on"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -Rv /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost pkaction"
            sleep 2
            CREATED_USERS="${USER_NAME} ${CREATED_USERS}"
        done
        rlRun "setsebool ssh_sysadm_login off"
        for USER_NAME in ${CREATED_USERS} ; do
            rlRun "userdel -rfZ ${USER_NAME}"
        done
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

