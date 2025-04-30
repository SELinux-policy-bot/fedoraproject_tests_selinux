#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/policycoreutils/Sanity/bz1731501-Test-semodule-l-checksum
#   Description: Test semodule -l --checksum
#   Author: Petr Lautrbach <plautrba@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        # create new type, allow reading, do not allow writing
        rlRun "cat << EOF >test_module.te
module test_module 1.0;

require {
    type unconfined_t;
    attribute filesystem_type;
    class file { getattr ioctl lock open read relabelto write };
    class filesystem { associate };
}

type test_t;

allow test_t filesystem_type:filesystem { associate };
allow unconfined_t test_t:file { getattr ioctl lock open read relabelto};
dontaudit unconfined_t test_t:file { write };
EOF"
        # compile the module
        rlRun "make -f /usr/share/selinux/devel/Makefile test_module.pp"
        # load it
        rlRun "semodule -X 500 -i test_module.pp"
        rlRun "/usr/libexec/selinux/hll/pp test_module.pp test_module.cil"

    rlPhaseEnd

    rlPhaseStartTest "semodule -lfull --checksum"
        rlRun "semodule -lfull --checksum | grep test_module"
        module=($(semodule -lfull --checksum | grep test_module) )
        sha256=($(sha256sum test_module.cil))
        rlAssertEquals "Is the module name 'test_module'?" ${module[1]} "test_module"
        rlAssertEquals "Is the module priority '500'?" ${module[0]} "500"
        rlAssertEquals "Is the loaded module checksum same as the file checksum? " ${module[3]} "sha256:${sha256[0]}"
    rlPhaseEnd

    rlPhaseStartTest "is the checksum option listed?"
        if [ -e "/usr/share/man/man8/semodule.8.gz" ]; then
            rlRun "man semodule | col -b | grep checksum"
            rlRun "man semodule | col -b | grep 'SHA256.*checksum'"
        fi
        rlRun "semodule --help | grep checksum"
        rlRun "semodule --help | grep 'checksum.*SHA256'"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semodule -X 500 -r test_module"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
