#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/anon_inode-and-similar
#   Description: Test coverage for cases verifying avc denial issues related to anon_inode tclass.
#   Author: Amith Kumar <apeetham@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="selinux-policy"

rlJournalStart
    if ! seinfo -c anon_inode | grep -q anon_inode ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm gcc
        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux policy prevents userfaultfds bz1974559"
        rlRun "gcc -o reproducer reproducer.c"
        tst_Time="$(date '+%T')"
        rlRun "./reproducer"
        sleep 3
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
        rlSESearchRule "allow unconfined_t unconfined_t : anon_inode { write }"
        rlRun "rm -f reproducer"
    rlPhaseEnd

    rlPhaseStartTest "mmap on io_uring - bz#2025714 + bz#2187745"
        rlSESearchRule "allow unconfined_t unconfined_t : anon_inode { map } [ ]"
        rlSESearchRule "allow svirt_t svirt_t : anon_inode { map } [ ]"
        rlSESearchRule "allow virtd_t virtd_t : anon_inode { map } [ ]"

        rlRun "fio --filename=/root/pokus --iodepth=16 --rw=write --ioengine=io_uring --bs=16k --size=2G --numjobs=30 --runtime=100s --group_reporting=1 --name=mytest"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

