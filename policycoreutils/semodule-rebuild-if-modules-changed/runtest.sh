#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2021 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

STORE_ROOT=/var/lib/selinux
STORE_TYPE=targeted
MODULES_ROOT="$STORE_ROOT/$STORE_TYPE/active/modules"
STORE_POLICY="$STORE_ROOT/$STORE_TYPE/active/policy.kern"
TEST_MODULE_DIR="$MODULES_ROOT/400/test_module"

CHECKSUM_CMD=sha256sum

function policy_checksum() {
    local policyvers="$1"

    "$CHECKSUM_CMD" "/etc/selinux/$STORE_TYPE/policy/policy.$policyvers"
}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm "libsemanage"
        rlAssertRpm "policycoreutils"

        policyvers="$(checkpolicy -V | cut -f 1 -d ' ')"
        policyvers_kernel="$(cat /sys/fs/selinux/policyvers)"
        if [ "$policyvers" -lt "$policyvers_kernel" ]; then
            policyvers="$policyvers_kernel"
        fi
    rlPhaseEnd

    rlPhaseStartTest
        if semodule --help | grep -q -- --rebuild-if-modules-changed; then
            rlRun "semodule -N -B" 0 \
                "Make sure policy store is in a consistent state initially"

            checksum_before="$(policy_checksum "$policyvers")"
            rlRun "semodule -N --rebuild-if-modules-changed"
            checksum_after="$(policy_checksum "$policyvers")"
            rlAssertEquals "Binary policy must not change after rebuild" \
                "$checksum_before" "$checksum_after"

            rlRun "semodule -N -B" 0 \
                "Make sure policy store is in a consistent state initially"

            rlLog "Inject a new module into the store"
            rlRun "mkdir -p \"\$TEST_MODULE_DIR\""
            rlRun "echo -n cil >\"\$TEST_MODULE_DIR/lang_ext\""
            rlRun "echo '(type test_module_type_t)' >\"\$TEST_MODULE_DIR/cil\""
            rlRun "semodule -N --rebuild-if-modules-changed" 0 \
                "Do a conditional rebuild"
            rlRun "semodule -l | grep test_module" 0 \
                "Verify that the module has been picked up"
            rlRun "seinfo -t test_module_type_t \"\$STORE_POLICY\" | grep test_module_type_t" 0 \
                "Verify that the new type is included in the built policy"

            rlLog "Now remove the module"
            rlRun "rm -rf \"\$TEST_MODULE_DIR\""
            rlRun "semodule -N --rebuild-if-modules-changed"
            rlRun "semodule -l | grep test_module" 1 \
                "Verify that the module has been removed"
            rlRun "seinfo -t test_module_type_t \"\$STORE_POLICY\" | grep test_module_type_t" 1 \
                "Verify that the new type is NOT included in the built policy"

            # Make sure policy is restored regardless of any previous failures
            rlRun "semodule -N -B" 0 \
                "Force a rebuild to clean things up"
            #rlRun "setsebool -NP daemons_use_tty=on"
            # TODO test changing booleans (persistently)
        else
            rlLog "--rebuild-if-modules-changed command-line option not supported; skipping tests..."
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
