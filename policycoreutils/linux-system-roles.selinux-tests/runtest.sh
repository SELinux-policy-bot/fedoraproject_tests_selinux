#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Run linux-system-roles.selinux (https://github.com/linux-system-roles/selinux.git) Ansible role tests
#   Author: Petr Lautrbach <plautrba@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2018 Red Hat, Inc.
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
        rlAssertRpm "git"
        if ! rpm -q ansible; then
            rlLog "There's no ansible rpm, trying: pip3 install ansible"
            rlRun "dnf -y install python3-pip"
            rlRun "pip3 install ansible"
            rlRun "ansible-playbook --version" 0
        else
            rlAssertRpm "ansible"
        fi
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "git clone https://github.com/linux-system-roles/selinux.git"
        rlRun "cd selinux/tests"

        for ansible_test in tests_*.yml; do
            if [ $ansible_test = "tests_all_transitions.yml" ]; then
                continue
            fi
            rlRun "ansible-playbook --skip-tags tests::bootc-e2e -i localhost, -c local -v $ansible_test"
        done

    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "cd ../../"
        rlRun "rm -rf selinux"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

