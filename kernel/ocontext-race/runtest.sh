#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PREFIX=/tmp/repro-
NTHREADS=8
TRIALS=20

function get_file_con() {
    getfattr -h --absolute-names --only-values -n security.selinux "$1" | tr -d '\000'
}

function strip_mls() {
    # strip the MLS -- mcstrans might be running, leading to different MLS
    # fields than expected
    sed 's/\([^:]*:[^:]*:[^:]*\):.*$/\1/g'
}

function check_file_con() {
    rlAssertEquals "Check expected context of $1" \
        "$(get_file_con "$1" | strip_mls)" \
        "$(echo "$2" | strip_mls)"
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r"

        rlRun "test \$(nproc) -ge 4" 0 "Test needs an SMP machine, otherwise it may pass regardless of the bug"

        rlRun "tmpdir=\$(mktemp -d)" 0 "Create a temporary directory"

        prefix="$tmpdir/repro-"

        for (( i = 0; i < $NTHREADS; i++ )); do
            rlRun "mkdir -p \"\${PREFIX}$i\"" 0 "Create subdirectory #$i"
        done
    rlPhaseEnd

for (( k = 0; k < $TRIALS; k++ )); do
    rlPhaseStartTest "Trial #$k"
        rlRun "load_policy" 0 "Reload SELinux policy to reset internal state"

        # NOTE: this must be ran in a single rlRun, otherwise beakerlib
        # overhead decreases the chance of a race condition 
        rlRun "
            for (( i = 0; i < $NTHREADS; i++)); do
                mount -t tmpfs tmpfs \"\${PREFIX}\$i\" &
            done
            wait
        " 0 "Create $NTHREADS tmpfs mounts at once"

        for (( i = 0; i < $NTHREADS; i++)); do
            rlRun "touch \"\${PREFIX}$i/file\"" 0 "Create a file in dir #$i"
            check_file_con "$PREFIX$i" "unconfined_u:object_r:user_tmp_t"
            check_file_con "$PREFIX$i/file" "unconfined_u:object_r:user_tmp_t"
        done

        for (( i = 0; i < $NTHREADS; i++)); do
            rlRun "umount \"\${PREFIX}$i\" &" 0 "Unmount dir #$i"
        done
    rlPhaseEnd
done

    rlPhaseStartCleanup
        rlRun "rm -rf \$tmpdir" 0 "Clean up the temporary directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
