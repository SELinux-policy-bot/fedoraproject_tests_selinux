#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2019-2022 Red Hat, Inc.
# Author: Milos Malik <mmalik@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"
    rlPhaseEnd

    rlPhaseStartTest "bz#1335986 + bz#1656787"
        rlRun "dmesg > before.txt"
        rlRun "while true; do load_policy; sleep 0.1; done &" 0 \
            "Start reloading the policy in a loop"

        function runcon_loop() {
            for (( i = 0; i < 1024; i++ )); do
                runcon -l s0:c$i true || return 1
            done
            return 0
        }
        rlRun "runcon_loop" 0 "Run runcon in a loop with varying contexts"
        rlRun "dmesg > after.txt"
        rlRun "diff before.txt after.txt | grep -e inode_doinit_with_dentry -e context_to_sid" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "kill \$(jobs -p)" 0 "Terminate background jobs"
        rlRun "wait" 0 "Wait for background jobs to terminate"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
