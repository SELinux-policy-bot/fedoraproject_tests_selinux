#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/policycoreutils/Regression/python-module-precedence-issue
#   Description: Tools like semanage must be hardened to avoid loading
#                rogue python modules that could lead to unexpected failures.
#   Author: Amith Kumar <apeetham@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
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

PACKAGE="policycoreutils"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "tmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $tmpDir"
    rlPhaseEnd

    rlPhaseStartTest "bz2128976 Tools must be hardened to not load rogue python modules"
        # Create a custom python script in /usr/sbin
cat > /usr/sbin/audit.py << EOF
import sys
print("BAD GUY!", file=sys.stderr)
sys.exit(1)
EOF
        # List all boolean records
        rlRun "semanage boolean -l > /dev/null" 0
    rlPhaseEnd

    rlPhaseStartCleanup
        # Remove irrelevant files
        rlRun "rm /usr/sbin/audit.py"
        rlRun "popd"
        rlRun "rm -r $tmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
