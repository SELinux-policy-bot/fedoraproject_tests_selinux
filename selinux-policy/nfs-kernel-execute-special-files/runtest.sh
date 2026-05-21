#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2026 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlImport 'selinux-policy/common' 0,1

        rlAssertRpm selinux-policy
        rlAssertRpm selinux-policy-targeted

        rlRun "uname -r" 0 "Print running kernel version"

        rlSESetEnforce
        rlSEStatus

        rlLog "Set up the test files"
        rlRun "tmpdir=\"\$(mktemp -d)\""
        rlRun "ln -s test \"\$tmpdir/link\""
        rlRun "mkfifo \"\$tmpdir/fifo\""
        rlRun "mknod \"\$tmpdir/chrdev\" c 1 3"
        rlRun "mknod \"\$tmpdir/blkdev\" b 0 7"
        rlRun "chmod ugo+rwx \"\$tmpdir/\"{fifo,chrdev,blkdev}"
        rlRun "ls -lZ \"\$tmpdir\""

        rlLog "Set up the NFS stuff"
        rlRun "systemctl start nfs-server"
        rlRun "exportfs -o rw,no_root_squash,fsid=0 \"localhost:\$tmpdir\""
        rlRun "mntpoint=\"\$(mktemp -d -p /mnt)\""
        rlRun "mount -t nfs -o nfsvers=4.1 localhost:/ \"\$mntpoint\""
    rlPhaseEnd

    rlPhaseStartTest "Policy rules"
        rlLog "kernel_t should be allowed the execute permission on special files"

        rlSESearchRule "allow kernel_t file_type:lnk_file  { execute } []"
        rlSESearchRule "allow kernel_t file_type:chr_file  { execute } []"
        rlSESearchRule "allow kernel_t file_type:blk_file  { execute } []"
        rlSESearchRule "allow kernel_t file_type:fifo_file { execute } []"
    rlPhaseEnd

    rlPhaseStartTest "Real scenario"
        rlLog "Should work with no AVCs"

        rlSESetTimestamp
        sleep 1
        for f in link fifo chrdev blkdev; do
            # We would like to test that access(2) actually succeeds, but
            # it currently fails anyway due to a kernel bug (fix pending).
            # Thus, ignore the exit code here for now.
            rlRun "python3 -c \"import os; assert os.access('\$mntpoint/$f', os.R_OK|os.X_OK, follow_symlinks=False)\"" 0-1
        done
        sleep 1
        rlSECheckAVC
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "umount \"\$mntpoint\""
        rlRun "rmdir \"\$mntpoint\""
        rlRun "exportfs -u \"localhost:\$tmpdir\""
        rlRun "systemctl stop nfs-server"
        rlRun "rm -rf \"\$tmpdir\""
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
