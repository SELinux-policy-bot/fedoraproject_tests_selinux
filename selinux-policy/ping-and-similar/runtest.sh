#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/ping-and-similar
#   Description: the service was running as initrc_t or init_t, now it is confined by SELinux
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
FILE_PATH="/bin/ping"
FILE_CONTEXT="ping_exec_t"
SERVICE_PACKAGE="iputils"
PROCESS_NAME="ping"
PROCESS_CONTEXT="ping_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if seinfo -c | grep -q icmp_socket ; then
    rlPhaseStartTest "bz#1552128"
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
        rlSESearchRule "allow ping_t ping_t : icmp_socket { create }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1596065"
        rlSEMatchPathCon "/usr/bin/ping" "ping_exec_t"
        rlSESearchRule "allow dhcpc_t ping_exec_t : file { map }"
    rlPhaseEnd
    fi

    if rlIsFedora '>=31' ; then
    rlPhaseStartTest "bz#1803759 + bz#1810403 + bz#1848929"
        # when unconfined users run ping, there is no transition to ping_t
        rlSESearchRule "allow unconfined_t node_t : icmp_socket { node_bind } [ ]"
        # when confined users run ping, a transition to ping_t happens
        rlSESearchRule "allow ping_t node_t : icmp_socket { node_bind } [ ]"
    rlPhaseEnd
    fi

    # this phase is useful if you want to run some commands under confined users
    rlPhaseStartTest "real scenario -- confined users"
        rlSEConfigureSSH

        rlRun "setsebool ssh_sysadm_login on"
        rlRun "setsebool user_ping on"
        for SELINUX_USER in staff_u user_u sysadm_u unconfined_u ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost ${FILE_PATH} -w 10 127.0.0.1"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost ${FILE_PATH} -c1 -W5 -I 0.0.0.0 127.0.0.1"
            rlRun "userdel -rfZ ${USER_NAME}"
        done
        rlRun "setsebool user_ping off"
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    # this phase is useful if there is a transition from initrc_t to ${PROCESS_CONTEXT} but there is no initscript or systemd unit file
    rlPhaseStartTest "real scenario -- runcon under root"
        rlRun "runcon system_u:system_r:initrc_t:s0 /bin/bash -c \"${FILE_PATH} -w 10 127.0.0.1\""
        rlRun "runcon system_u:system_r:initrc_t:s0 /bin/bash -c \"${FILE_PATH} -c1 -W5 -I 0.0.0.0 127.0.0.1\""
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlRun "service sshd restart"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

