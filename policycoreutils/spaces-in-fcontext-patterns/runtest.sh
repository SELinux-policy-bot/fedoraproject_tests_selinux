#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/policycoreutils/Regression/spaces-in-fcontext-patterns
#   Description: Does semanage accept spaces in fcontext patterns?
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

PACKAGE="policycoreutils"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlRun "rpm -qf `which semanage`"
    rlPhaseEnd

    rlPhaseStartTest "bz#1893545"
        rlRun "semanage fcontext -l -C"
        rlRun "semanage fcontext -a -t public_content_t '/mnt/media/My\ Dir(/.*)?'" 1
        rlRun "semanage fcontext -a -t public_content_t '/mnt/media/My	Dir(/.*)?'" 1
        rlRun "semanage fcontext -a -t public_content_t '/mnt/media/MyDir(/.*)?'" 1
        rlRun "semanage fcontext -l -C"
        rlRun "semanage fcontext -d -t public_content_t '/mnt/media/My\ Dir(/.*)?'" 1
        rlRun "semanage fcontext -d -t public_content_t '/mnt/media/My	Dir(/.*)?'" 1
        rlRun "semanage fcontext -d -t public_content_t '/mnt/media/MyDir(/.*)?'" 1
        rlRun "semanage fcontext -l -C"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

