#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

function check_avc_begin() {
    sleep 1.1
    date +'%x %T'
    sleep 1.1
}

function check_avc_end() {
    marker="marker-$RANDOM"

    auditctl -m "$marker"

    for (( i = 0; i < 100; i++ )); do
        if ausearch -i -m user -ts $1 2>/dev/null </dev/null | \
            grep -q "$marker"
        then
            echo $i
            break
        fi
        sleep 0.1
    done

    ausearch -i -m avc -ts $1 </dev/null
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print kernel version"

        for prog in sctp_bz2048251_client sctp_bz2048251_server; do
            rlRun "gcc -O2 -Wall -o $prog sctp_common.c $prog.c -lsctp" 0 \
                "Compile $prog"
        done
        rlRun "modprobe sctp" 0 "Ensure SCTP module is loaded"
        rlRun "mkfifo flag" 0 "Create a fifo file for test"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "audit_ts=\"\$(check_avc_begin)\""

        rlRun "./sctp_bz2048251_server -f flag -4 9999 &" 0 "Start the server"
        rlRun "read -t 5 <>flag" 0 "Wait for the server to start listening"
        rlRun "./sctp_bz2048251_client 127.0.0.1 9999" 0 "Run the client"
        rlRun "wait" 0 "Wait for the server to exit"

        rlRun "check_avc_end \"\$audit_ts\"" 1 "Check if there are AVC denials"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f sctp_bz2048251_client sctp_bz2048251_server flag"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
