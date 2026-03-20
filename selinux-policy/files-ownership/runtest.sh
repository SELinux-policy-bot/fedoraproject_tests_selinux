#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of selinux-policy/files-ownership/runtest.sh
#   Description: test if selinux-policy owns tree with interface files
#   Author: Veronika Syncakova <vsyncako@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm selinux-policy
    rlPhaseEnd

    rlPhaseStartTest "RHEL-141659 + RHEL-157952 + FC-1681"
        for LOCATION in devel devel/include devel/include/distributed \
            packages/targeted packages/minimum packages/mls; do
            rlRun -s "rpm -qf /usr/share/selinux/${LOCATION}"
            rlAssertGrep "selinux-policy-" $rlRun_LOG -i
            rm -f $rlRun_LOG
        done
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd