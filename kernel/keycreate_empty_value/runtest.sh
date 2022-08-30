#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

EXE="reproducer"

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"

        enable_container=0
        if semodule -l | grep -q container; then
            rlRun "semodule -d container" 0 "Disable the container module"
            enable_container=1
        fi

        rlRun "gcc -o $EXE reproducer.c" 0 "Compile the reproducer"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "./$EXE" 0 "Run the reproducer"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f $EXE" 0 "Remove the reproducer binary"

        if [ "$enable_container" -eq 1 ]; then
            rlRun "semodule -e container" 0 "Re-enable the container module"
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
