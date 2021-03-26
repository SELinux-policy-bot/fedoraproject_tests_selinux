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

        rlRun "echo '(fsuse xattr ramfs (system_u object_r fs_t ((s0) (s0))))' >ramfs_xattr.cil"
        rlRun "semodule -i ramfs_xattr.cil"
        rlRun "mkdir /mnt/test-ramfs"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "mount -t ramfs none /mnt/test-ramfs"
        rlRun "[ \"\$(secon -t -f /mnt/test-ramfs)\" = ramfs_t ]"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "umount /mnt/test-ramfs" 0-1
        rlRun "rmdir /mnt/test-ramfs"
        rlRun "semodule -r ramfs_xattr"
        rlRun "rm -f ramfs_xattr.cil"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
