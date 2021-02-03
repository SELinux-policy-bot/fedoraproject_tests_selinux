#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2021 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

function boolGet() {
    getsebool "$1" | cut -d ' ' -f 3
}
function boolSet() {
    getsebool "$1" &>/dev/null || return 0
    setsebool "$1" "$2" || return 1
    [ "$(boolGet "$1")" == "$2" ]
}

TEST_BOOLEAN="domain_can_mmap_files"

rlJournalStart
    rlPhaseStartSetup
        rlRun "bool_default=\$(boolGet domain_can_mmap_files)" 0 \
            "Get the initial boolean value"
        rlRun "auditctl -a exclude,never -F subj_user=sysadm_u" 0 \
            "Add an audit rule that triggers the bug"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "setsebool domain_can_mmap_files $(( 1 - $bool_default )) &" 0 \
            "Start setsebool in the background (it may hang)"
        rlRun "sleep 5s" 0 "Give it a grace period of 5 seconds"
        rlRun "test \$(jobs -r | wc -l) -eq 0" 0 "Check that it has exited"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "auditctl -d exclude,never -F subj_user=sysadm_u" 0 \
            "Remove the audit rule"
        rlRun "boolSet domain_can_mmap_files $bool_default" 0 \
            "Restore the boolean value"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
