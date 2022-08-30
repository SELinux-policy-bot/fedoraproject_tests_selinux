# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

EXE4="reproducer4"
EXE6="reproducer6"
PORT=8000

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"

        rlRun "gcc -o $EXE4 reproducer4.c" 0 "Compile the IPv4 reproducer"
        rlRun "gcc -o $EXE6 reproducer6.c" 0 "Compile the IPv6 reproducer"
        rlRun "nc -4lk $PORT &" 0 "Start IPv4 server"
        rlRun "nc -6lk $PORT &" 0 "Start IPv6 server"
    rlPhaseEnd

    rlPhaseStartTest "IPv4"
        rlRun "strace ./$EXE4 $PORT" 0 "Run the IPv4 reproducer"
    rlPhaseEnd

    rlPhaseStartTest "IPv6"
        rlRun "strace ./$EXE6 $PORT" 0 "Run the IPv6 reproducer"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f $EXE4" 0 "Removing the IPv4 reproducer binary"
        rlRun "rm -f $EXE6" 0 "Removing the IPv6 reproducer binary"
        rlRun "kill %1" 0 "Kill the IPv4 server"
        rlRun "kill %2" 0 "Kill the IPv6 server"
        rlRun "wait $(jobs -p)" 0 "Wait for the servers to terminate"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
