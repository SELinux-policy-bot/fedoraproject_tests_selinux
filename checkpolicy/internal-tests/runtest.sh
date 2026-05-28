#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/checkpolicy/internal-tests
#   Description: Run internal checkpolicy tests
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc.
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

PACKAGE="checkpolicy"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        if ! rpm -q libsepol-static >& /dev/null ; then
            rlRun "dnf install -y libsepol-static --enablerepo '*'"
        fi
        rlRun "rpm -qa | grep libsepol | sort"
    rlPhaseEnd

    rlPhaseStartTest "non-fuzzing tests"
        rlRun "dnf download --source ${PACKAGE}"
        rlRun "rpm -ivh ${PACKAGE}-*.src.rpm"
        rlRun "rm -f ${PACKAGE}-*.src.rpm"
        rlRun "tar zxf ~/rpmbuild/SOURCES/${PACKAGE}-*.tar.gz"
        rlRun "pushd ${PACKAGE}-*"
        rlRun "make test"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf ~/rpmbuild ${PACKAGE}-*"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

