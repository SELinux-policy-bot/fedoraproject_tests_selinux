#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

function trigger_modprobe() {
    # ensure gre modules are unloaded
    modprobe -r ip_gre gre || return 2
    ip link add mygre type gretap local 127.0.0.1 remote 127.0.0.1
    ret=$?
    ip link del mygre 2>/dev/null
    if [ $ret -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

rlJournalStart
    rlPhaseStartSetup
        rlImport 'selinux-policy/common'

        rlAssertRpm selinux-policy
        rlAssertRpm selinux-policy-targeted

        rlSESetEnforce
        rlSEStatus

        original_modprobe="$(sysctl -nb kernel.modprobe)"
        original_core_pattern="$(sysctl -nb kernel.core_pattern)"

        rlRun "gcc -o trigger_segfault trigger_segfault.c"
    rlPhaseEnd

    rlPhaseStartTest "Policy rules"
        rlLog "kernel_t shouldn't be allowed to execute any file without transition"

        # Only check execute_no_trans and a couple of unexpected type
        # transitions. Plain 'execute' has to be allowed broadly due to
        # overlayfs mounter checks. (Think overlayfs mounted before policy
        # is loaded.)
        rlSESearchRule "allow kernel_t file_type:file { execute_no_trans } []" 1 \
            "kernel_t shouldn't be allowed to execute any file without transition"
        rlSESearchRule "type_transition kernel_t user_home_t:process domain;" 1 \
            "kernel_t shouldn't have any transition defined over files in user home directories"
        rlSESearchRule "type_transition kernel_t user_tmp_t:process domain;" 1 \
            "kernel_t shouldn't have any transition defined over user temporary files"
    rlPhaseEnd

    rlPhaseStartTest "Legit modprobe"
        rlLog "Should work with no AVCs"

        rlSESetTimestamp
        sleep 1
        rlRun "trigger_modprobe"
        sleep 1
        rlSECheckAVC
    rlPhaseEnd

    rlPhaseStartTest "Modprobe set to /usr/bin/true"
        rlLog "Should fail but cause no AVCs"

        rlRun "sysctl kernel.modprobe=/usr/bin/true" 0 \
            "Set kernel.modprobe to /usr/bin/true"
        rlSESetTimestamp
        sleep 1
        rlRun "trigger_modprobe" 1
        sleep 1
        rlSECheckAVC
        rlRun "sysctl kernel.modprobe=\"\$original_modprobe\"" 0 \
            "Reset kernel.modprobe to default"
    rlPhaseEnd

    rlPhaseStartTest "Modprobe set to /usr/sbin/load_policy"
        rlLog "Should fail with AVCs denying the execution"

        rlRun "sysctl kernel.modprobe=/usr/sbin/load_policy" 0 \
            "Set kernel.modprobe to /usr/sbin/load_policy"
        rlSESetTimestamp
        sleep 1
        rlRun "trigger_modprobe" 1
        sleep 1
        rlRun "rlSEAVCCheck" 1
        rlRun "sysctl kernel.modprobe=\"\$original_modprobe\"" 0 \
            "Reset kernel.modprobe to default"
    rlPhaseEnd

    rlPhaseStartTest "Modprobe relabeled to bin_t"
        rlLog "Should fail with AVCs denying operation after transition"
        rlRun "chcon -t bin_t \"\$(readlink -f \"\$original_modprobe\")\"" 0 \
            "Set kernel.modprobe to /usr/sbin/load_policy"
        rlSESetTimestamp
        sleep 1
        rlRun "trigger_modprobe" 1
        sleep 1
        rlRun "rlSEAVCCheck" 1
        rlRun "restorecon \"\$(readlink -f \"\$original_modprobe\")\"" 0 \
            "Reset kernel.modprobe to default"
    rlPhaseEnd

    rlPhaseStartTest "Legit coredump helper"
        rlLog "Should work with no AVCs"

        rlSESetTimestamp
        sleep 1
        rlRun "./trigger_segfault" 139
        sleep 2
        rlSECheckAVC
    rlPhaseEnd

    rlPhaseStartTest "Core pattern set to |/usr/sbin/load_policy"
        rlLog "Should fail with AVCs denying the execution"

        rlRun "sysctl kernel.core_pattern='|/usr/sbin/load_policy'" 0 \
            "Set kernel.core_pattern to |/usr/sbin/load_policy"
        rlSESetTimestamp
        sleep 1
        rlRun "./trigger_segfault" 139
        sleep 1
        rlRun "rlSEAVCCheck" 1
        rlRun "sysctl kernel.core_pattern=\"\$original_core_pattern\"" 0 \
            "Reset kernel.core_pattern to default"
    rlPhaseEnd

    rlPhaseStartTest "Core pattern set to |/usr/bin/false"
        rlLog "Should work with no AVCs"

        rlRun "sysctl kernel.core_pattern='|/usr/bin/false'" 0 \
            "Set kernel.core_pattern to |/usr/bin/false"
        rlSESetTimestamp
        sleep 1
        rlRun "./trigger_segfault" 139
        sleep 2
        rlSECheckAVC
        rlRun "sysctl kernel.core_pattern=\"\$original_core_pattern\"" 0 \
            "Reset kernel.core_pattern to default"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f trigger_segfault"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
