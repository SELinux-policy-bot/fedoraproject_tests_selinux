#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2021 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

TEST_PORT=8080

FG_URL="https://github.com/brendangregg/FlameGraph"
FG_DIR="FlameGraph"

LIMIT="1%"

rlJournalStart
if [ $(nproc) -lt 8 ]; then
    rlPhaseStartTest "SKIP"
        rlLog "At least 8 cores needed to run this test, skipping..."
    rlPhaseEnd
else
    rlPhaseStartSetup
        rlImport "distribution/epel"
        rlRun "command -v hping3 || epelyum install -y hping3" 0 \
            "Make sure hping3 is installed (EPEL-only on RHEL)"

        rlRun "uname -r"

        rlRun "git clone $FG_URL $FG_DIR"
    rlPhaseEnd

    rlPhaseStartTest
        ip_address="$(ip -o addr show up scope global | head -n 1 |
            awk '{ print $4 }' | cut -f 1 -d '/')"

        rlRun "nc -l $TEST_PORT &" 0 "Start a TCP server"
        for (( i = 0; i < $(nproc) / 2; i++ )); do
            rlRun "hping3 $ip_address -q -p $TEST_PORT -S --flood &" 0 \
                "Start TCP flood #$i"
        done
        rlRun "perf record -o perf.data -ag -- sleep 10s" 0 \
            "Capture perf data for 10s"
        rlRun "kill \$(jobs -p)" 0 "Kill background processes"
        rlRun "perf report -i perf.data -g none --pretty raw -F overhead,symbol | grep -E '\\[k\\] (selinux|security)_'"
        top_percent="$(perf report -i perf.data -g none --pretty raw -F overhead,symbol | \
            grep -E '\[k\] (selinux|security)_' | head -n 1 | awk '{ print $1 }')"
        rlRun "[ \"\$({ echo \$top_percent; echo $LIMIT; } | sort -n | tail -n 1)\" = $LIMIT ]" 0 \
            "Check that no SELinux function takes up more than $LIMIT of CPU time"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "perf script -i perf.data | $FG_DIR/stackcollapse-perf.pl | $FG_DIR/flamegraph.pl > flamegraph.svg"
        rlRun "xz -T0 perf.data"

        rlFileSubmit "perf.data.xz"
        rlFileSubmit "flamegraph.svg"
    rlPhaseEnd
fi
rlJournalPrintText
rlJournalEnd
