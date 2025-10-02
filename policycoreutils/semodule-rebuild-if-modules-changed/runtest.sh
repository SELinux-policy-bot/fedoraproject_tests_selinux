#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2021 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

if grep -q ^store-root /etc/selinux/semanage.conf ; then
    STORE_ROOT=`grep ^store-root /etc/selinux/semanage.conf | cut -d = -f 2`
else
    STORE_ROOT=/var/lib/selinux
fi
STORE_TYPE=targeted
MODULES_ROOT="$STORE_ROOT/$STORE_TYPE/active/modules"
STORE_POLICY="$STORE_ROOT/$STORE_TYPE/active/policy.kern"
STORE_BOOLS="$STORE_ROOT/$STORE_TYPE/active/booleans.local"
STORE_DISABLE_DONTAUDIT="$STORE_ROOT/$STORE_TYPE/active/disable_dontaudit"
TEST_MODULE_DIR="$MODULES_ROOT/400/test_module"
TEST_BOOLEAN="xguest_exec_content"
TEST_BOOLEAN_VALUE="0"
TEST_BOOLEAN_VALUE_TEXT="false"

CHECKSUM_CMD=sha256sum

function policy_checksum() {
    local policyvers="$1"

    "$CHECKSUM_CMD" "/etc/selinux/$STORE_TYPE/policy/policy.$policyvers"
}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm "libsemanage"
        rlAssertRpm "policycoreutils"
        rlAssertRpm "selinux-policy"

        policyvers="$(checkpolicy -V | cut -f 1 -d ' ')"
        policyvers_kernel="$(cat /sys/fs/selinux/policyvers)"
        if [ "$policyvers" -lt "$policyvers_kernel" ]; then
            policyvers="$policyvers_kernel"
        fi

        rlRun "semodule -N -B" 0 \
            "Make sure policy store is in a consistent state initially"

        refresh_opt=""
        for opt in --refresh --rebuild-if-modules-changed; do
            if semodule --help | grep -q -- "$opt"; then
                refresh_opt="$opt"
                rlLog "$opt command-line option detected for semodule"
                break
            fi
        done
    rlPhaseEnd

    if [ -n "$refresh_opt" ]; then
        rlPhaseStartTest "No change behavior"
            # The resulting binary policy will be different (albeit
            # equivalent) after a full rebuild vs. when only local
            # changes are applied to existing policy.linked file, so
            # toggle a boolean twice to get the expected binary form.
            rlRun "setsebool -P xguest_exec_content $TEST_BOOLEAN_VALUE"
            rlRun "setsebool -P xguest_exec_content $(( ! $TEST_BOOLEAN_VALUE ))"

            checksum_before="$(policy_checksum "$policyvers")"
            rlRun "semodule -N $refresh_opt"
            checksum_after="$(policy_checksum "$policyvers")"
            rlAssertEquals "Binary policy must not change after rebuild" \
                "$checksum_before" "$checksum_after"

            # Make sure policy is restored regardless of any previous failures
            rlRun "semodule -N -B" 0 \
                "Force a rebuild to clean things up"
        rlPhaseEnd

        rlPhaseStartTest "Module injected"
            rlLog "Inject a new module into the store"
            rlRun "mkdir -p '$TEST_MODULE_DIR'"
            rlRun "echo -n cil >'$TEST_MODULE_DIR/lang_ext'"
            rlRun "echo '(type test_module_type_t)' >'$TEST_MODULE_DIR/cil'"
            rlRun "semodule -N $refresh_opt" 0 \
                "Do a conditional rebuild"
            rlRun "semodule -l | grep test_module" 0 \
                "Verify that the module has been picked up"
            rlRun "seinfo -t test_module_type_t '$STORE_POLICY' | grep test_module_type_t" 0 \
                "Verify that the new type is included in the built policy"

            rlLog "Now remove the module"
            rlRun "rm -rf '$TEST_MODULE_DIR'"
            rlRun "semodule -N $refresh_opt"
            rlRun "semodule -l | grep test_module" 1 \
                "Verify that the module has been removed"
            rlRun "seinfo -t test_module_type_t '$STORE_POLICY' | grep test_module_type_t" 1 \
                "Verify that the new type is NOT included in the built policy"

            # Make sure policy is restored regardless of any previous failures
            rlRun "semodule -N -B" 0 \
                "Force a rebuild to clean things up"
        rlPhaseEnd

        # --refresh option implies fixed boolean/etc. behavior
        if [ "$refresh_opt" = "--refresh" ]; then
            rlPhaseStartTest "Boolean setting injected"
                rlLog "Inject a boolean setting into the store"
                rlRun "echo '$TEST_BOOLEAN=$TEST_BOOLEAN_VALUE' >'$STORE_BOOLS'"
                rlRun "semodule -N $refresh_opt" 0 \
                    "Do a conditional rebuild"
                rlRun "seinfo -xb '$TEST_BOOLEAN' '$STORE_POLICY' | grep -F -- '$TEST_BOOLEAN_VALUE_TEXT;'" 0 \
                    "Verify that the boolean setting has been picked up"

                rlLog "Now remove the setting"
                rlRun "rm -f '$STORE_BOOLS'"
                rlRun "semodule -N $refresh_opt"
                rlRun "seinfo -xb '$TEST_BOOLEAN' '$STORE_POLICY' | grep -F -- '$TEST_BOOLEAN_VALUE_TEXT;'" 1 \
                    "Verify that the boolean setting has been reset back"

                # Make sure policy is restored regardless of any previous failures
                rlRun "semodule -N -B" 0 \
                    "Force a rebuild to clean things up"
            rlPhaseEnd

            # https://bugzilla.redhat.com/show_bug.cgi?id=2173959
            if ! { rlIsRHEL && rlIsRHEL '<9.3'; }; then
                rlPhaseStartTest "Disable dontaudit injected"
                    rlLog "Inject disable_dontaudit flag into the store"
                    rlRun "touch '$STORE_DISABLE_DONTAUDIT'"
                    rlRun "semodule -N $refresh_opt" 0 \
                        "Do a conditional rebuild"
                    rlRun "test \$(sesearch --dontaudit '$STORE_POLICY' | wc -l) -eq 0" 0 \
                        "Verify that the flag has been picked up"

                    rlLog "Now remove the flag"
                    rlRun "rm -f '$STORE_DISABLE_DONTAUDIT'"
                    rlRun "semodule -N $refresh_opt"
                    rlRun "test \$(sesearch --dontaudit '$STORE_POLICY' | wc -l) -gt 0" 0 \
                        "Verify that the dontaudit rules are back"

                    # Make sure policy is restored regardless of any previous failures
                    rlRun "semodule -N -B" 0 \
                        "Force a rebuild to clean things up"
                rlPhaseEnd
            fi
        fi
    else
        rlPhaseStartTest "Test skipped"
            rlLog "--rebuild-if-modules-changed/--refresh command-line option not supported; skipping tests..."
        rlPhaseEnd
    fi
rlJournalPrintText
rlJournalEnd
