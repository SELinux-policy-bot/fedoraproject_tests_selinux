#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/ksm-and-similar
#   Description: SELinux interferes with ksm and related programs
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
FILE_PATH="/usr/libexec/ksmctl"
FILE_CONTEXT="ksm_exec_t"
SERVICE_NAME="ksm"
PROCESS_NAME="ksmctl"
PROCESS_CONTEXT="ksm_t"

rlJournalStart
    if rlIsRHEL 7 ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qf ${FILE_PATH}"

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /usr/lib/systemd/system/ksm.service

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined ${PROCESS_CONTEXT} ; then
    rlPhaseStartTest "bz#2021131"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/sys/kernel/mm/ksm" "sysfs_t"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlSESearchRule "allow ${PROCESS_CONTEXT} sysfs_t : dir { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2091416 + bz#2091417 + bz#2091418"
        rlSEMatchPathCon "/usr/libexec/ksmctl" "ksm_exec_t"
        rlSEMatchPathCon "/sys/kernel/mm/ksm" "sysfs_t"
        rlSEMatchPathCon "/sys/kernel/mm/ksm/run" "sysfs_t"
        rlSESearchRule "allow ksm_t sysfs_t : dir { write add_name } [ ]"
        rlSESearchRule "allow ksm_t sysfs_t : file { create } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlRun "sed -i 's/^ConditionVirtualization=.*$//' /usr/lib/systemd/system/ksm.service"
        rlRun "systemctl daemon-reload"
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlRun "systemctl daemon-reload"
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

