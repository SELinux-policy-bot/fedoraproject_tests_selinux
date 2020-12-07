#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-notify-and-similar
#   Description: SELinux interferes with systemd-notify and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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
SERVICE_PACKAGE="systemd"

rlJournalStart
    rlLog "If this test fails, please contact mmalik on IRC #selinux"
    rlLog "This test should fail if tested bugs are NOT fixed yet"
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1903305"
        rlSEMatchPathCon "/usr/bin/systemd-notify" "systemd_notify_exec_t"
        rlSESearchRule "allow init_t unconfined_t : fifo_file { write } [ ]"
        rlSESearchRule "allow systemd_notify_t user_devpts_t : chr_file { read write append } [ ]"
        rlSESearchRule "allow systemd_notify_t systemd_notify_t : capability { net_admin } [ ]"
        rlSESearchRule "allow systemd_notify_t kernel_t : unix_dgram_socket { sendto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#1903305"
        rlRun "NOTIFY_SOCKET=/run/systemd/notify systemd-notify --ready"
        sleep 1
        rlRun "NOTIFY_SOCKET=/run/systemd/notify systemd-notify --ready"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- runcon under root"
        rlRun "NOTIFY_SOCKET=/run/systemd/notify runcon system_u:system_r:initrc_t:s0 bash -c 'systemd-notify --ready'"
        sleep 1
        rlRun "NOTIFY_SOCKET=/run/systemd/notify runcon system_u:system_r:initrc_t:s0 bash -c 'systemd-notify --ready'"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- unconfined service uses systemd-notify"
        rlRun "cp -f notifier.sh /usr/local/bin/"
        rlRun "cp -f local-notifier.service /usr/lib/systemd/system/"
        rlRun "restorecon -v /usr/local/bin/notifier.sh /usr/lib/systemd/system/local-notifier.service"
        rlRun "systemctl daemon-reload"
        rlRun "service local-notifier start"
        sleep 2
        rlRun "service local-notifier status"
        rlRun "rm -f /usr/lib/systemd/system/local-notifier.service /usr/local/bin/notifier.sh"
        rlRun "systemctl daemon-reload"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

