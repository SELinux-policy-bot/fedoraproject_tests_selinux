#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/policycoreutils/Regression/selinux-autorelabel-service
#   Description: incorrectly set StandardInput and StandardOutput of selinux-autorelabel service
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="policycoreutils"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
    rlPhaseEnd

    rlPhaseStartTest "bz#1766578 + bz#1778094"
        rlRun "grep ^Standard /usr/lib/systemd/system/selinux-autorelabel.service"
        rlRun "grep 'StandardInput.*tty' /usr/lib/systemd/system/selinux-autorelabel.service" 1
        rlRun "grep -e 'StandardOutput.*journal.console' -e 'StandardOutput.*console.journal' /usr/lib/systemd/system/selinux-autorelabel.service"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

