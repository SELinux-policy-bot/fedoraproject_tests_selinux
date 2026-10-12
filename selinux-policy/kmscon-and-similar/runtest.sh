#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/kmscon-and-similar
#   Description: SELinux interferes kmscon and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
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
#   License along with this program; if not, see
#   <https://www.gnu.org/licenses/>.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
FILE_PATH="/usr/bin/kmscon"
SERVICE_NAME="kmscon"
PROCESS_NAME="kmscon"
if seinfo -t | grep -q kmscon ; then
    FILE_CONTEXT="kmscon_exec_t"
    PROCESS_CONTEXT="kmscon_t"
else
    FILE_CONTEXT="bin_t"
    PROCESS_CONTEXT="unconfined_service_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qf ${FILE_PATH}"

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if grep -q 'ELN 11' /etc/fedora-release ; then
    rlPhaseStartTest "policy rules check"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSESearchRule "allow kmscon_t kmscon_t : capability2 { bpf } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "cp -f /usr/lib/systemd/system/${SERVICE_NAME}.service /etc/systemd/system/"
        rlRun "sed -i 's|^.*ConditionPathExists.*$||' /etc/systemd/system/${SERVICE_NAME}.service"
        rlRun "systemctl daemon-reload"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 2
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 2
        rlRun "rm -f /etc/systemd/system/${SERVICE_NAME}.service"
        rlRun "systemctl daemon-reload"
    rlPhaseEnd
    fi

    # TODO: add test phase for kmsconvt@.service
    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

