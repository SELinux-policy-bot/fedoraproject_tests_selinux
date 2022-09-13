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

        rlRun "dd if=/dev/zero of=diskfile bs=4M count=1"
        rlRun "mkfs.vfat diskfile"
        DEVICE="$(losetup -f)"
        rlRun "losetup $DEVICE diskfile"

        rlRun "echo '(fsuse xattr vfat (system_u object_r fs_t ((s0) (s0))))' >vfat_xattr.cil"
        rlRun "semodule -i vfat_xattr.cil"
        rlRun "mkdir /mnt/test-vfat"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "mount -t vfat $DEVICE /mnt/test-vfat"
        rlRun "[ \"\$(secon -t -f /mnt/test-vfat)\" = dosfs_t ]"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "umount /mnt/test-vfat" 0-1
        rlRun "rmdir /mnt/test-vfat"
        rlRun "semodule -r vfat_xattr" 0-1
        rlRun "rm -f vfat_xattr.cil"

        rlRun "losetup -d $DEVICE" 0-1
        rlRun "rm -f diskfile"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
