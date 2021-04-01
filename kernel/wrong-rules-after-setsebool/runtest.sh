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
        rlRun "sesearch -s ftpd_t -t public_content_rw_t -c dir -p create -A | \
            tee sesearch-before.txt"
        rlRun "setsebool ftpd_anon_write=off ftpd_connect_all_unreserved=off \
            ftpd_connect_db=off ftpd_full_access=off"
        rlRun "sesearch -s ftpd_t -t public_content_rw_t -c dir -p create -A | \
            tee sesearch-after.txt"
        rlAssertNotDiffer "sesearch-before.txt" "sesearch-after.txt"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f sesearch-before.txt sesearch-after.txt"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
