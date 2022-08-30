#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2018-2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"
        rlRun "touch testfile"
        reset_enforcing=0
        if [ "$(getenforce)" = "Enforcing" ]; then
            rlRun "setenforce 0" 0 "Switch to permissive"
            reset_enforcing=1
        fi
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "setfattr -n security.selinux -v 'a\\0aaaaaaaaaaaaaaaa' testfile" 0 \
            "Try to set a label with a null char in it"
        rlRun "getfattr -e hex -n security.selinux testfile"
        rlRun "getfattr -e hex -n security.selinux testfile | grep -E '0x6100[0-9a-f]+'" 1 \
            "Check for junk in the output of getfattr"
    rlPhaseEnd

    rlPhaseStartCleanup
        if [ "$reset_enforcing" -eq 1 ]; then
            rlRun "setenforce 1" 0 "Switch back to enforcing"
        fi
        rlRun "rm -f testfile"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
