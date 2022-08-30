#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

FG_URL="https://github.com/brendangregg/FlameGraph"
FG_DIR="FlameGraph"

TARGET_SYMBOL="security_secid_to_secctx"
LIMIT="10.00%"

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"

        rlRun "git clone $FG_URL $FG_DIR"
    rlPhaseEnd

    rlPhaseStartTest
        JOURNALD_PID=$(pidof systemd-journald)
        rlLog "PID of systemd-journald is $JOURNALD_PID"

        rlRun "cat /dev/urandom | base64 | logger &" 0 \
            "Flood systemd-journald with data"
        rlRun "timeout 30s perf record -o perf.data -p $(pidof systemd-journald) -g --call-graph dwarf" 124 \
            "Capture perf data on systemd-journald"
        rlRun "kill %1"

        rlRun "perf script -i perf.data | $FG_DIR/stackcollapse-perf.pl | $FG_DIR/flamegraph.pl > flamegraph.svg"

        rlRun "perf report -i perf.data -g none --pretty raw | grep $TARGET_SYMBOL"
        PERCENT="$(perf report -g none --pretty raw | grep $TARGET_SYMBOL | \
            grep -Eo '[0-9]+\.[0-9]+%' | head -n 1)"
        rlLog "Detected that $TARGET_SYMBOL took up $PERCENT of time (limit $LIMIT)."
        rlRun "{ echo \$PERCENT; echo \$LIMIT; } | sort -n | tail -n 1 | grep \$LIMIT" 0 \
            "Check that time usage is within limit"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileSubmit "perf.data"
        rlFileSubmit "flamegraph.svg"

        rlRun "rm -rf $FG_DIR"
        rlRun "rm -f perf.data flamegraph.svg"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
