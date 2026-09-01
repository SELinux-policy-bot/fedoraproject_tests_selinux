#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of rebuild-and-install-checkpolicy
#   Description: runs package rebuild and install if needed by reverse dependency
#   Author: Jan Onderka <jonderka@redhat.com>
#   Author: Petr Lautrbach <lautrbach@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
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
#   License along with this program; if not, see
#   <https://www.gnu.org/licenses/>.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="checkpolicy"
RPMBUILDDIR="$(rpm -E '%{_topdir}')"
ARCH_VERSION="$(uname -m)"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlRun "rm -rf ${RPMBUILDDIR} ${PACKAGE}*"
        rlRun "mkdir -p ${RPMBUILDDIR}"
        rlRun "pushd ${RPMBUILDDIR}"
        rlFetchSrcForInstalled ${PACKAGE}
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "Source code tests"
        PACKAGE_VERSION="$(rpm -qp --qf '%{version}\n' ${RPMBUILDDIR}/checkpolicy-*.src.rpm)"
        rlLogInfo "PACKAGE_VERSION=${PACKAGE_VERSION}"
        rlRun "dnf builddep -y ${RPMBUILDDIR}/checkpolicy-*.src.rpm"
        rlRun "DIST=$(rpm --eval '%{dist}')"
        rlRun -t "rpmbuild --rebuild --define '%dist $DIST.rebuild' ${RPMBUILDDIR}/checkpolicy-*.src.rpm"

        if [[ -n "${SAVE_RPMBUILD_DATA:-}" ]]; then
            rlRun "ls ${PACKAGE}*.src.rpm > ${TMT_TEST_DATA}/src.version"
            rlRun "cp ${RPMBUILD}/checkpolicy-*.src.rpm ${TMT_TEST_DATA}/"
        fi

        rlRun "dnf install -y ${RPMBUILDDIR}/RPMS/${ARCH_VERSION}/${PACKAGE}-${PACKAGE_VERSION}*.rpm"

        rlLog "$(rpm -qa | grep checkpolicy)"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf ${RPMBUILDDIR}"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
