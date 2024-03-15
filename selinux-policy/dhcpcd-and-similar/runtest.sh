#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/dhcpcd-and-similar
#   Description: SELinux interferes with dhcpcd and related programs
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
FILE_PATH="/usr/sbin/dhcpcd"
FILE_CONTEXT="dhcpc_exec_t"
SERVICE_PACKAGE="dhcpcd"
SERVICE_NAME="dhcpcd"
PROCESS_NAME="dhcpcd"
PROCESS_CONTEXT="dhcpc_t"

rlJournalStart
    rlPhaseStartSetup
        if rlIsRHEL 4 5 6 ; then
            rlLog "Not applicable to this OS version."
            rlJournalEnd
            exit 0
        fi

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

    rlPhaseStartTest "bz#1585971 + bz#1602343"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/dhcpcd" "dhcpc_var_run_t"
        rlSEMatchPathCon "/var/run/dhcpcd/sock" "dhcpc_var_run_t"
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
        rlSESearchRule "allow dhcpc_t dhcpc_t : netlink_generic_socket { create bind }"
        rlSESearchRule "allow dhcpc_t dhcpc_t : netlink_kobject_uevent_socket { create setopt bind getattr }"
        rlSESearchRule "allow dhcpc_t dhcpc_t : rawip_socket { create setopt }"
        rlSESearchRule "allow dhcpc_t var_run_t : dir { write add_name }"
        rlSESearchRule "type_transition dhcpc_t var_run_t : sock_file dhcpc_var_run_t"
        rlSESearchRule "allow dhcpc_t dhcpc_var_run_t : sock_file { create unlink }"
    rlPhaseEnd

    if rlIsRHEL 9 || rlIsCentOS 9 ; then
    rlPhaseStartTest "RHEL-15326"
        rlSESearchRule "allow dhcpc_t dhcpc_t : capability2 { bpf } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 8 ; then
    rlPhaseStartTest "bz#2269708 + bz#2270733"
        rlSEMatchPathCon "/run/netns" "ifconfig_var_run_t"
        rlSESearchRule "allow dhcpc_t ifconfig_var_run_t : dir { read } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "ip netns add test-ns"
        rlRun "ip netns del test-ns"
        rlRun "ls -lZR /run/netns"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

