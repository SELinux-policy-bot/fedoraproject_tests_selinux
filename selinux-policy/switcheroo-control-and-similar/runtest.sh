#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/switcheroo-control-and-similar
#   Description: SELinux interferes with switcheroo-control and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/libexec/switcheroo-control"
SERVICE_PACKAGE="switcheroo-control"
SERVICE_NAME="switcheroo-control"
PROCESS_NAME="switcheroo-control"
if seinfo -t | grep -q switcheroo ; then
    PROCESS_CONTEXT="switcheroo_t"
    FILE_CONTEXT="switcheroo_exec_t"
else
    PROCESS_CONTEXT="unconfined_service_t"
    FILE_CONTEXT="bin_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "switcherooctl version"
        rlRun "switcherooctl list"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlRun "touch ./empty-file"
        rlRun "switcherooctl launch ./empty-file" 0,1
        rlRun "rm -f ./empty-file"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

