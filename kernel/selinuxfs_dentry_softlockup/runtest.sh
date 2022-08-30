#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"
    rlPhaseEnd

    rlPhaseStartTest
        rlAssertGreaterOrEqual "Ensure the machine has at least two cores" \
            "$(nproc)" 2

        rlRun "(cd /sys/fs/selinux; while true; do find >/dev/null 2>&1; done) &"
        rlRun "while true; do load_policy; sleep 0.1; done &"

        function check_soft_lockup() {
            for (( i = 0; i < 60; i++ )); do
                dmesg | grep 'BUG: soft lockup' && return 1
                sleep 1
            done
            return 0
        }
        rlRun "check_soft_lockup" 0 "Wait and see if soft lockup appears in dmesg"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "kill \$(jobs -p)" 0 "Terminate background jobs"
        rlRun "wait" 0 "Wait for background jobs to terminate"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
