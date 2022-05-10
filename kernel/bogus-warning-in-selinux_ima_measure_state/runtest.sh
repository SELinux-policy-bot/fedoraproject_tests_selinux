#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

function trigger_the_bug() {
    while true; do echo 0 > /sys/fs/selinux/checkreqprot; done &
    while true; do load_policy; done &

    sleep 15s

    kill $(jobs -p)
    wait $(jobs -p)
    return 0
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Show the running kernel version"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "trigger_the_bug" 0 "Run the reproducer"
        rlRun "dmesg | grep -E 'WARNING:.*selinux_ima_measure_state'" 1 \
            "Check that dmesg doesn't contain relevant WARNING lines"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
