#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/opensmtpd-and-similar
#   Description: SELinux interferes with the opensmtpd service and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/sbin/smtpd"
FILE_CONTEXT="sendmail_exec_t"
SERVICE_PACKAGE="opensmtpd"
SERVICE_NAME="opensmtpd"
PROCESS_NAME="smtpd"
PROCESS_CONTEXT="sendmail_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        if ! rpm -q ${SERVICE_PACKAGE} ; then
            rlRun "yum -y install ${SERVICE_PACKAGE} --enablerepo epel" 0,1
        else
            rlAssertRpm ${SERVICE_PACKAGE}
        fi

        rlServiceStop ${SERVICE_NAME} postfix sendmail

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 8 && ! rlIsCentOS 8 ; then
    rlPhaseStartTest "bz#2208696"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/smtpd.sock" "sendmail_var_run_t"
        rlSESearchRule "allow sendmail_t sendmail_t : capability { sys_chroot fowner } [ ]"
        rlSESearchRule "type_transition sendmail_t var_run_t : sock_file sendmail_var_run_t"
        rlSESearchRule "allow sendmail_t sendmail_var_run_t : sock_file { create setattr unlink write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2246115"
        rlSEMatchPathCon "/run/smtpd.sock" "sendmail_var_run_t"
        rlSESearchRule "allow sendmail_t sendmail_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-15175"
        # actions on the /var/run/smtpd.pid file
        rlSESearchRule "allow sendmail_t sendmail_var_run_t : file { create getattr open unlink write } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        if ! ls -Z ${FILE_PATH} | grep -q ${FILE_CONTEXT} ; then
            # for environments where the service is not yet confined
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "sestatus | mailx -s test-email root@localhost"
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlRun "smtpctl show status"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME} postfix sendmail
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

