#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-creds
#   Description: SELinux interferes with services which use credentials
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
SERVICE_PACKAGE="systemd"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlRun "cp dmesg.service /etc/systemd/system/"
        rlRun "systemctl daemon-reload"

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#2096857 + bz#2097681"
        rlSEMatchPathCon "/usr/bin/systemd-creds" "bin_t"
        rlSEMatchPathCon "/dev/shm" "tmpfs_t"
        rlSESearchRule "allow init_t tmpfs_t : file { read write open setattr rename create } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "a systemd service loading credentials"
        rlRun "setsebool daemons_use_tty on"
        rlRun "echo hello > /foo"
        rlRun "ls -alZ /foo"
        rlRun "systemd-creds encrypt /foo /bar"
        rlRun "ls -alZ /bar"
        rlRun "systemctl start dmesg.service" 0-255
        rlRun "systemctl status dmesg.service" 0-255
        rlRun "systemctl stop dmesg.service" 0-255
        rlRun "systemctl status dmesg.service" 0-255
        rlRun "rm -f /foo /bar"
        rlRun "systemd-run -P --wait -p LoadCredential=abc:/etc/hosts systemd-creds cat abc"
        rlRun "setsebool daemons_use_tty off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlRun "rm -f /etc/systemd/system/dmesg.service"
        rlRun "systemctl daemon-reload"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

