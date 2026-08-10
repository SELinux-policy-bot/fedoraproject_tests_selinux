#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2021 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r"
    rlPhaseEnd

    rlPhaseStartTest
        rlAssertExists /sys/kernel/tracing/events/avc/selinux_audited/enable
        rlRun "perf list | grep avc:selinux_audited"
        rlRun "perf record -o perf.data -e avc:selinux_audited -g \
            runcon system_u:system_r:kernel_t:s0 echo" 0-255
        rlRun "perf script -i perf.data"
        rlAssertGreater "'perf script' output should have more than 0 lines" \
            "$(perf script -i perf.data | wc -l)" "0"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f perf.data"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
