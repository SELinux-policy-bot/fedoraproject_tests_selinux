#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2024 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "gcc -o reproducer reproducer.c" 0 "Build the reproducer"

        rlRun "netlabelctl cipsov4 add pass doi:16 tags:1" 0
        rlRun "netlabelctl map del default" 0
        rlRun "netlabelctl map add default address:0.0.0.0/0 protocol:unlbl" 0
        rlRun "netlabelctl map add default address:::/0 protocol:unlbl" 0
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "./reproducer 127.0.0.1 9999" 0 "Run the reproducer"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f reproducer" 0  "Remove the reproducer binary"

        rlRun "netlabelctl map del default" 0
        rlRun "netlabelctl cipsov4 del doi:16" 0
        rlRun "netlabelctl map add default protocol:unlbl" 0
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
