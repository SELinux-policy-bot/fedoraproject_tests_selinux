#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/logwatch-and-similar
#   Description: SELinux interferes with logwatch and related programs
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
FILE_CONTEXT="logwatch_exec_t"
SERVICE_PACKAGE="logwatch"
SERVICE_NAME="logwatch"
PROCESS_NAME="logwatch"
PROCESS_CONTEXT="logwatch_t"

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

    if ! rlIsRHEL 9 ; then
    rlPhaseStartTest "bz#2270484"
        rlSEMatchPathCon "/usr/share/logwatch/scripts/logwatch.pl" "logwatch_exec_t"
        rlSEMatchPathCon "/usr/sbin/sendmail.sendmail" "sendmail_exec_t"
        rlSEMatchPathCon "/run/systemd/sessions/" "systemd_logind_sessions_t"
        rlSESearchRule "allow logwatch_t systemd_logind_sessions_t : dir { read } [ ]"
        rlSESearchRule "type_transition logwatch_t sendmail_exec_t : process logwatch_mail_t"
        rlSESearchRule "allow logwatch_mail_t init_t : unix_stream_socket { getattr } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for environments where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- timer"
        rlRun "systemctl enable ${SERVICE_NAME}.timer"
        rlRun "systemctl start ${SERVICE_NAME}.timer"
        rlRun "systemctl list-timers --all"
        rlRun "sleep 5s"
        rlRun "systemctl stop ${SERVICE_NAME}.timer"
        rlRun "systemctl disable ${SERVICE_NAME}.timer"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

