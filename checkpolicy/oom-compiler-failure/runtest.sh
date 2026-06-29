#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/checkpolicy/Regression/oom-compiler-failure
#   Description: checkpolicy and checkmodule must fail cleanly under OOM
#   Author: Petr Matyas <pmatyas@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
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

. /usr/share/beakerlib/beakerlib.sh

PACKAGE="checkpolicy"

# Virtual memory limit in KB applied to each compiler subprocess.
# 8 MB is below the minimum needed to parse a real targeted policy binary
# but above the minimum for the process to load its shared libraries and
# start executing.  Validated against checkpolicy 3.x on RHEL-10.
MEM_LIMIT_KB=8192

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm policycoreutils
        rlAssertExists "/usr/bin/checkpolicy"
        rlAssertExists "/usr/bin/checkmodule"
        rlAssertExists "/usr/bin/semodule_unpackage"

        # Locate the active compiled policy on disk.
        POLICY_BINARY=$(find /etc/selinux/ -name "policy.*" -type f | head -1)
        rlAssertExists "${POLICY_BINARY}"
        rlLog "Using policy binary: ${POLICY_BINARY}"

        # Extract the base module binary so checkmodule can compile it back.
        # semodule_unpackage accepts .pp and writes separate .mod and .fc files.
        rlRun "semodule -E base" 0 "Extract base.pp from the active policy store"
        rlAssertExists "base.pp"
        rlRun "semodule_unpackage base.pp base.mod base.fc" 0 "Unpack base.pp into base.mod"
        rlAssertExists "base.mod"
        rlLog "base.mod size: $(stat -c %s base.mod) bytes"
    rlPhaseEnd

    rlPhaseStartTest "checkpolicy fails without producing output under OOM"
        rlRun "rm -f policy.oom"
        # Run checkpolicy in a child process whose virtual address space is
        # capped.  exec replaces the shell so ulimit applies only to checkpolicy
        # itself, leaving the test harness unaffected.
        rlRun -s "bash -c 'ulimit -v ${MEM_LIMIT_KB}; exec checkpolicy -b -M -o policy.oom ${POLICY_BINARY}'" 1-255 \
            "checkpolicy must exit non-zero when memory is exhausted"
        rlLog "checkpolicy output: $(cat ${rlRun_LOG})"
        rlRun "test ! -s policy.oom" 0 \
            "checkpolicy must not produce an output binary under OOM"
    rlPhaseEnd

    rlPhaseStartTest "checkmodule fails without producing output under OOM"
        rlRun "rm -f base.oom"
        rlRun -s "bash -c 'ulimit -v ${MEM_LIMIT_KB}; exec checkmodule -b -M -o base.oom base.mod'" 1-255 \
            "checkmodule must exit non-zero when memory is exhausted"
        rlLog "checkmodule output: $(cat ${rlRun_LOG})"
        rlRun "test ! -s base.oom" 0 \
            "checkmodule must not produce an output binary under OOM"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f policy.oom base.oom base.pp base.mod base.fc"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
