#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2021 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Set this parameter to 1 to also generate a flamegraph.
GENERATE_FLAMEGRAPH="${GENERATE_FLAMEGRAPH:-0}"

TEST_PORT=8080

FG_URL="https://github.com/brendangregg/FlameGraph"
FG_DIR="FlameGraph"

function isBefore() {
    local target="$1"
    local reference="$2"

    grep -E "$target|$reference" | head -n 1 | grep -q "$target"
}

rlJournalStart
if [ $(nproc) -lt 64 ]; then
    rlPhaseStartTest "SKIP"
        rlLog "At least 64 cores needed to run this test, skipping..."
    rlPhaseEnd
else
    rlPhaseStartSetup
        rlImport "epel/epel"
        rlRun "command -v hping3 || epelyum install -y hping3" 0 \
            "Make sure hping3 is installed (EPEL-only on RHEL)"

        rlRun "uname -r"

        if [ "$GENERATE_FLAMEGRAPH" != 0 ]; then
            rlRun "git clone $FG_URL $FG_DIR"
        fi
    rlPhaseEnd

    rlPhaseStartTest
        ip_address="$(ip -o addr show up scope global | head -n 1 |
            awk '{ print $4 }' | cut -f 1 -d '/')"

        rlRun "nc -l $TEST_PORT &" 0 "Start a TCP server"
        for (( i = 0; i < $(nproc) / 2; i++ )); do
            rlRun "hping3 $ip_address -q -p $TEST_PORT -S --flood &" 0 \
                "Start TCP flood #$i"
        done
        rlRun "perf record -o perf.data -ag -- sleep 5s" 0 \
            "Capture perf data for 5s"
        rlRun "kill \$(jobs -p)" 0 "Kill background processes"
        rlRun "perf report -i perf.data -g none --pretty raw -F overhead,symbol | \
            grep -E '\\[k\\] (selinux|security)_' | tee perf-report.txt"

        if grep -q selinux_peerlbl_enabled /proc/kallsyms; then
            rlLog "selinux_peerlbl_enabled() found in /proc/kallsyms"
            target_func=selinux_peerlbl_enabled
        else
            rlLog "selinux_peerlbl_enabled() NOT found in /proc/kallsyms (ergo it's inlined)"
            # if selinux_peerlbl_enabled() is inlined, then the extra overhead
            # shows up in selinux_ip_postroute() and selinux_socket_sock_rcv_skb()
            target_func=selinux_ip_postroute
        fi
        rlRun "cat perf-report.txt | isBefore security_netlbl_sid_to_secattr $target_func" 0 \
            "Check that $target_func() has lower impact than security_netlbl_sid_to_secattr()"
    rlPhaseEnd

    rlPhaseStartCleanup
        if [ "$GENERATE_FLAMEGRAPH" != 0 ]; then
            rlRun "perf script -i perf.data | $FG_DIR/stackcollapse-perf.pl | $FG_DIR/flamegraph.pl > flamegraph.svg"
            rlFileSubmit "flamegraph.svg"
            rlRun "rm -f flamegraph.svg"
        fi
        rlRun "xz -T0 perf.data"

        for file in "perf.data.xz" "perf-report.txt"; do
            rlFileSubmit "$file"
            rlRun "rm -f $file"
        done
    rlPhaseEnd
fi
rlJournalPrintText
rlJournalEnd
