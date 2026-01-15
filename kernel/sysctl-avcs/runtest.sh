#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2026 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r"

        SE_ROLE="$(secon -r --pid $$)"
        SE_TYPE="$(secon -t --pid $$)"

        rlRun "make -f /usr/share/selinux/devel/Makefile test_policy.pp M4PARAM='-D TEST_ROLE=$SE_ROLE -D TEST_TYPE=$SE_TYPE'" 0 \
            "Build the test policy"
        rlRun "semodule -i test_policy.pp" 0 "Load test policy"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "runcon -t test_domain_t sysctl -a"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semodule -r test_policy" 0 "Unload test policy"
        rlRun "make -f /usr/share/selinux/devel/Makefile clean" 0 \
            "Clean the test policy"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
