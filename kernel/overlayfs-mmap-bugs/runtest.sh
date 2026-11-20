#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2025 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print current running kernel version"

        SE_USER="$(secon -u --pid $$)"
        SE_ROLE="$(secon -r --pid $$)"
        SE_TYPE="$(secon -t --pid $$)"
        SE_MLS="$(secon -m --pid $$)"

        OVERLAYCON="$SE_USER:object_r:test_mountedfile_t:s0"
        DYNTRANSCON="$SE_USER:$SE_ROLE:test_access_exploit_t:$SE_MLS"

        rlRun "gcc -o map_access map_access.c" 0 \
            "Build the test program"
        rlRun "chcon -t bin_t map_access" 0 "Relabel the test program"
        rlRun "make -f /usr/share/selinux/devel/Makefile test_policy.pp M4PARAM='-D TEST_ROLE=$SE_ROLE -D TEST_TYPE=$SE_TYPE'" 0 \
            "Build the test policy"
        rlRun "semodule -i test_policy.pp" 0 "Load test policy"

        rlRun "mkdir lowerdir" 0 "Create lowerdir"
        rlRun "touch lowerdir/file_ok lowerdir/file_no_map lowerdir/file_no_read lowerdir/file_no_write" 0 \
            "Create test files"
        rlRun "chcon -R -t test_lowerfile_t lowerdir"
        rlRun "chcon -t test_lowerfile_no_map_t lowerdir/file_no_map"
        rlRun "chcon -t test_lowerfile_no_write_t lowerdir/file_no_write"
        rlRun "chcon -t test_lowerfile_no_read_t lowerdir/file_no_read"
        for layer in layer1 layer2; do
            rlRun "mkdir $layer"
            rlRun "mkdir $layer/upperdir $layer/workdir $layer/mountpoint" 0 \
                "Create test dirs ($layer)"
            rlRun "chcon -R -t test_lowerfile_t $layer/workdir $layer/upperdir"
        done

        rlRun ":>/var/log/audit/audit.log; rm -f /var/log/audit/audit.log.*" 0 \
            "Clear the audit log"

        rlRun "runcon -t test_mounter_t mount -t overlay none -o 'context=$OVERLAYCON,lowerdir=./lowerdir,upperdir=./layer1/upperdir,workdir=./layer1/workdir' layer1/mountpoint" 0 \
            "Mount the overlay filesystem (1st layer)"
    rlPhaseEnd

    rlPhaseStartTest "CVE-2026-46054"
        # Bug 1
        # Should get below AVC:
        # avc:  denied  { map } for scontext=...test_mounter_t... tcontext=...test_lowerfile_no_map_t... tclass=file
        rlRun "runcon -t test_access_full_t ./map_access ./layer1/mountpoint/file_no_map RDONLY SHARED" 3 "Test Bug 1"

        # Bug 2, result 1
        # Shouldn't get below AVC:
        # avc:  denied  { use } for scontext=...test_access_full_t... tcontext=...test_mounter_t... tclass=fd
        rlRun "setsebool domain_fd_use 0"
        rlRun "runcon -t test_access_full_t ./map_access ./layer1/mountpoint/file_ok RDONLY SHARED" 0 "Test Bug 2, result 1"
        rlRun "setsebool domain_fd_use 1"

        # Bug 2, result 2
        # Shouldn't get below AVC:
        # avc:  denied  { read } for scontext=...test_access_full_t... tcontext=...test_lowerfile_t... tclass=file
        rlRun "runcon -t test_access_full_t ./map_access ./layer1/mountpoint/file_ok RDONLY SHARED" 0 "Test Bug 2, result 2"

        # Bug 2, result 3
        # Should get below AVC:
        # avc:  denied  { read } for scontext=...test_access_exploit_t... tcontext=...test_mountedfile_t... tclass=file
        rlRun "runcon -t test_access_full_t ./map_access ./layer1/mountpoint/file_ok RDONLY SHARED $DYNTRANSCON" 5 "Test Bug 2, result 3"
    rlPhaseEnd

    rlPhaseStartTest "execmem regression"
        rlRun "runcon -t test_access_full_t ./map_access ./layer1/mountpoint/file_ok RDONLY PRIVATE" 0 "Verify no execmem denied"
    rlPhaseEnd

    rlPhaseStartTest "CVE-2026-46054 - 2 layers"
        rlLog "Retry CVE-2026-46054 tests with two layers of overlayfs"
        rlLog "This also verifies CVE-2026-98214"

        rlRun "umount ./layer1/mountpoint"

        rlRun "runcon -t test_mounter_t mount -t overlay none -o 'lowerdir=./lowerdir,upperdir=./layer1/upperdir,workdir=./layer1/workdir' layer1/mountpoint" 0 \
            "Mount the overlay filesystem (1st layer)"

        rlRun "runcon -t test_mounter_t mount -t overlay none -o 'context=$OVERLAYCON,lowerdir=./layer1/mountpoint,upperdir=./layer2/upperdir,workdir=./layer2/workdir' layer2/mountpoint" 0 \
            "Mount the overlay filesystem (2nd layer)"

        # Bug 1
        # Should get below AVC:
        # avc:  denied  { map } for scontext=...test_mounter_t... tcontext=...test_lowerfile_no_map_t... tclass=file
        rlRun "runcon -t test_access_full_t ./map_access ./layer2/mountpoint/file_no_map RDONLY SHARED" 3 "Test Bug 1"

        # Bug 2, result 1
        # Shouldn't get below AVC:
        # avc:  denied  { use } for scontext=...test_access_full_t... tcontext=...test_mounter_t... tclass=fd
        rlRun "setsebool domain_fd_use 0"
        rlRun "runcon -t test_access_full_t ./map_access ./layer2/mountpoint/file_ok RDONLY SHARED" 0 "Test Bug 2, result 1"
        rlRun "setsebool domain_fd_use 1"

        # Bug 2, result 2
        # Shouldn't get below AVC:
        # avc:  denied  { read } for scontext=...test_access_full_t... tcontext=...test_lowerfile_t... tclass=file
        rlRun "runcon -t test_access_full_t ./map_access ./layer2/mountpoint/file_ok RDONLY SHARED" 0 "Test Bug 2, result 2"

        # Bug 2, result 3
        # Should get below AVC:
        # avc:  denied  { read } for scontext=...test_access_exploit_t... tcontext=...test_mountedfile_t... tclass=file
        rlRun "runcon -t test_access_full_t ./map_access ./layer2/mountpoint/file_ok RDONLY SHARED $DYNTRANSCON" 5 "Test Bug 2, result 3"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "ausearch -i -m avc" 0 "Show AVC denials"

        rlRun "umount ./layer2/mountpoint"
        rlRun "umount ./layer1/mountpoint"
        rlRun "rm -rf lowerdir layer1 layer2"

        rlRun "semodule -r test_policy" 0 "Unload test policy"
        rlRun "make -f /usr/share/selinux/devel/Makefile clean" 0 \
            "Clean the test policy"
        rlRun "rm -f map_access" 0 "Remove the test program"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
