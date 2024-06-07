#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2023 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Beaker compat
if [ -n "$JOBID" ] && [ -n "$TESTID" ]; then
    function tmt-reboot() { rstrnt-reboot; }
    TMT_REBOOT_COUNT="$REBOOTCOUNT"
fi

function installDepsYum() {
    local yum="$1"; shift

    if "$yum" install --help | grep -q -- --skip-unavailable; then
        "$yum" install -y --skip-unavailable $*
    elif "$yum" install --help | grep -q -- --skip-broken; then
        "$yum" install -y --skip-broken $*
    else
        for req in $*; do
            if ! rpm -q --quiet --whatprovides "$req"; then
                "$yum" install -y "$req" || true
            fi
        done
    fi
}

function installDeps() {
    if type yum >/dev/null; then
        installDepsYum yum "$@"
    elif type dnf >/dev/null; then
        installDepsYum dnf "$@"
    fi
}

rlJournalStart
if [ $TMT_REBOOT_COUNT -lt 1 ]; then
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print initial running kernel version"

        uname="$(uname -r)"
        raw_uname="${uname%+*}"
        debug_uname="${raw_uname}+debug"
        echo "$uname" >"$BEAKERLIB_DIR/orig_uname"
        echo "$debug_uname" >"$BEAKERLIB_DIR/debug_uname"
        if [ "$uname" = "$debug_uname" ]; then
            rlLog "Already running the debug kernel, nice!"
        else
            rlLog "Install and boot the debug kernel"

            rlRun "installDeps kernel-debug-$raw_uname"
            rlRun "grubby --set-default /boot/vmlinuz-$debug_uname"
        fi

        rlRun "grubby --update-kernel /boot/vmlinuz-$debug_uname --args kmemleak=on" 0 \
            "Enable kmemleak on the debug kernel"
        if command -v zipl >/dev/null; then
            rlRun "zipl" 0 "Run zipl"
        fi
        tmt-reboot
fi
if [ $TMT_REBOOT_COUNT -lt 2 ]; then
        rlRun "uname -r" 0 "Print running kernel version after reboot"
        rlRun "cat /proc/cmdline" 0 "Print kernel cmdline after reboot"

        rlRun "mkdir -p /mnt/test_mount" 0 \
            "Create a directory for the test mount"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "echo clear > /sys/kernel/debug/kmemleak" 0 \
            "Clear the kmemleak buffer"

        rlRun "mount -t tmpfs -o context=system_u:object_r:user_tmp_t:s0 tmpfs /mnt/test_mount" 0 \
            "Do a context mount"
        rlRun "umount /mnt/test_mount" 0 \
            "Unmount the context mount"

        # For whatever reason this needs to be run twice...
        rlRun "echo scan > /sys/kernel/debug/kmemleak" 0 \
            "Trigger a kmemleak scan"
        rlRun "cat /sys/kernel/debug/kmemleak >/dev/null" 0 \
            "Dump the kmemleak buffer once"
        rlRun "echo scan > /sys/kernel/debug/kmemleak" 0 \
            "Trigger a second kmemleak scan"

        rlLog "Check that /sys/kernel/debug/kmemleak is empty"
        rlAssertNotDiffer /sys/kernel/debug/kmemleak /dev/null
        rlRun "cat /sys/kernel/debug/kmemleak" 0 \
            "Dump the kmemleak buffer"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rmdir /mnt/test_mount" 0 \
            "Remove the directory for the test mount"
        uname="$(cat "$BEAKERLIB_DIR/orig_uname")"
        debug_uname="$(cat "$BEAKERLIB_DIR/debug_uname")"
        rlRun "grubby --update-kernel /boot/vmlinuz-$debug_uname --remove-args kmemleak=on" 0 \
            "Undo kmemleak enabling"
        rlRun "grubby --set-default /boot/vmlinuz-$uname" 0 \
            "Switch the default back to the initial kernel version"
        if command -v zipl >/dev/null; then
            rlRun "zipl" 0 "Run zipl"
        fi
        tmt-reboot
fi
        rlRun "uname -r" 0 \
            "Print running kernel version after cleanup reboot"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
