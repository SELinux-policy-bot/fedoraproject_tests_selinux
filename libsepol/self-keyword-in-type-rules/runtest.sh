#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

MODULES_BAD="test_self_tt_bad1 test_self_tt_bad2 test_self_tt_bad3 test_self_tt_bad4"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm "libsepol"
        rlAssertRpm "checkpolicy"
        rlAssertRpm "policycoreutils"
        rlAssertRpm "selinux-policy"
    rlPhaseEnd

    rlPhaseStartTest "Test good TE module"
        rlRun "make -f /usr/share/selinux/devel/Makefile test_self_tt_good.pp" 0 \
            "Test that test_self_tt_good TE module can be built"
        rlRun "semodule -i test_self_tt_good.pp" 0 \
            "Test that test_self_tt_good TE module can be installed"
        rlRun "diff rules_expected.txt <(sesearch -T --type_change --type_member -rd -D 'test_[efg]_t' | sort)" 0 \
            "Test that the resulting binary policy rules match the expected ones"
        rlRun "semodule -r test_self_tt_good" 0 \
            "Remove the test_self_tt_good TE module"
    rlPhaseEnd

    rlPhaseStartTest "Test good CIL module"
        rlRun "semodule -i test_self_tt_good.cil" 0 \
            "Test that test_self_tt_good CIL module can be installed"
        rlRun "diff rules_expected.txt <(sesearch -T --type_change --type_member -rd -D 'test_[efg]_t' | sort)" 0 \
            "Test that the resulting binary policy rules match the expected ones"
        rlRun "semodule -r test_self_tt_good" 0 \
            "Remove the test_self_tt_good CIL module"
    rlPhaseEnd

    rlPhaseStartTest "Test bad TE modules"
        for i in {1..8}; do
            rlRun "make -f /usr/share/selinux/devel/Makefile test_self_tt_bad$i.pp" 0-2 \
                "Try to build test_self_tt_bad$i TE module"
            rlRun "semodule -i test_self_tt_bad$i.pp" 1 \
                "Test that test_self_tt_bad$i TE module cannot be installed"
            rlRun "semodule -r test_self_tt_bad$i" 1 \
                "Try to remove the test_self_tt_bad$i TE module"
        done
    rlPhaseEnd

    rlPhaseStartTest "Test bad CIL modules"
        for i in {1..8}; do
            rlRun "semodule -i test_self_tt_bad$i.cil" 1 \
                "Test that test_self_tt_bad$i CIL module cannot be installed"
            rlRun "semodule -r test_self_tt_bad$i" 1 \
                "Try to remove the test_self_tt_bad$i CIL module"
        done
    rlPhaseEnd

    rlJournalPrintText
rlJournalEnd
