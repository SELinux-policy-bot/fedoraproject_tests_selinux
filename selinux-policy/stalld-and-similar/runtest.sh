#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/stalld-and-similar
#   Description: SELinux interferes with stalld and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/bin/stalld"
FILE_CONTEXT="stalld_exec_t"
SERVICE_PACKAGE="stalld"
SERVICE_NAME="stalld"
PROCESS_NAME="stalld"
PROCESS_CONTEXT="stalld_t"

rlJournalStart
    if ! rpm -q ${SERVICE_PACKAGE} ; then
        rlLog "Required packages are not available/installed."
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
        rlFileBackup /etc/sysconfig/stalld

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#2042614"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlRun "ls -Z /proc/sys/kernel/sched_rt_runtime_us | grep :sysctl_kernel_t:"
        rlRun "ls -Z /sys/kernel/debug/sched/debug | grep :debugfs_t:"
        rlRun "ls -Z /sys/kernel/debug/sched/features | grep :debugfs_t:"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlSESearchRule "allow ${PROCESS_CONTEXT} sysctl_kernel_t : file { getattr open read } [ fips_mode ]"
        rlSESearchRule "allow ${PROCESS_CONTEXT} debugfs_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2092864"
        rlSESearchRule "allow stalld_t stalld_t : capability { sys_nice } [ ]"
        rlSESearchRule "allow stalld_t stalld_t : process { setsched } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2096776"
        rlSESearchRule "allow stalld_t kernel_t : process { getsched } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2102224"
        rlSESearchRule "allow stalld_t kernel_t : process { setsched } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2105038"
        rlRun "sesearch -s stalld_t -t domain -c process -p getsched -A -ds -dt | grep allow"
        rlRun "sesearch -s stalld_t -t domain -c process -p setsched -A -ds -dt | grep allow"
    rlPhaseEnd

    rlPhaseStartTest "bz#2140673"
        rlRun "ls -Z /sys/kernel/security/lockdown | grep :security_t"
        rlSESearchRule "allow stalld_t security_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "sed -i 's/^LOGGING=.*$/LOGGING=--log_syslog/' /etc/sysconfig/stalld"
        rlRun "journalctl -u ${SERVICE_NAME} > before.txt"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "sed -i 's/^LOGGING=.*$/LOGGING=--log_kmsg/' /etc/sysconfig/stalld"
        rlRun "journalctl -u ${SERVICE_NAME} > after.txt"
        rlRun "setsebool domain_can_write_kmsg on"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
        rlRun "setsebool domain_can_write_kmsg off"
        rlRun "diff before.txt after.txt | grep -i -e 'operation not permitted' -e 'permission denied'" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rm -f before.txt after.txt
        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

