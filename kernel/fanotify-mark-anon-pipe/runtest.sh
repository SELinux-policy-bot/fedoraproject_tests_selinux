#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2026 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print kernel version"

        rlRun "gcc -o reproducer reproducer.c" 0 "Compile the reproducer"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "./reproducer" 0 "Run the reproducer"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f reproducer" 0 "Delete the reproducer binary"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
