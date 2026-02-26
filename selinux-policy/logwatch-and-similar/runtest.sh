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
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/systemd/system/logwatch.timer

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL "<9.5" ; then
    rlPhaseStartTest "bz#2183432 + RHEL-34135"
        rlRun "ls -Z /proc/sys/net/ipv6/conf/all/disable_ipv6 | grep :sysctl_net_t"
        rlSESearchRule "allow logwatch_mail_t sysctl_net_t : dir { search } [ ]"
        rlSESearchRule "allow logwatch_mail_t sysctl_net_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 9 && ! rlIsCentOS 9 ; then
    rlPhaseStartTest "bz#2270484"
        rlSEMatchPathCon "/usr/share/logwatch/scripts/logwatch.pl" "logwatch_exec_t"
        rlSEMatchPathCon "/usr/sbin/sendmail.sendmail" "sendmail_exec_t"
        rlSEMatchPathCon "/run/systemd/sessions/" "systemd_logind_sessions_t"
        rlSESearchRule "allow logwatch_t systemd_logind_sessions_t : dir { read } [ ]"
        rlSESearchRule "type_transition logwatch_t sendmail_exec_t : process logwatch_mail_t"
        if rlIsFedora ; then
            rlSESearchRule "allow logwatch_mail_t init_t : unix_stream_socket { getattr } [ ]"
        fi
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "mkdir -p /var/cache/logwatch"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for environments where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.timer ] ; then
    rlPhaseStartTest "real scenario -- timer"
        rlRun "systemctl enable ${SERVICE_NAME}.timer"
        rlRun "systemctl start ${SERVICE_NAME}.timer"
        rlRun "systemctl list-timers --all"
        NEXT_TIME=`date -d "now + 1 minute" "+%H:%M"`
        rlRun "cp -f /usr/lib/systemd/system/${SERVICE_NAME}.timer /etc/systemd/system/"
        rlRun "sed -i 's/AccuracySec=.*$/AccuracySec=1s\nOnCalendar=*-*-* $NEXT_TIME/' /etc/systemd/system/${SERVICE_NAME}.timer"
        rlRun "systemctl daemon-reload"
        rlRun "systemctl list-timers --all"
        rlRun "sleep 2m"
        rlRun "systemctl stop ${SERVICE_NAME}.timer"
        rlRun "systemctl disable ${SERVICE_NAME}.timer"
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

