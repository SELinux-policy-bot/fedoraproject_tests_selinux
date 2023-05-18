#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Beaker compat
if [ -n "$JOBID" ] && [ -n "$TESTID" ]; then
    function tmt-reboot() { rstrnt-reboot; }
    TMT_REBOOT_COUNT="$REBOOTCOUNT"
fi

rlJournalStart
if [ $TMT_REBOOT_COUNT -lt 1 ]; then
    rlPhaseStartSetup "Setup"
        rlRun "uname -r" 0 "Kernel version before reboot"

        rlRun "install -d /usr/lib/dracut/modules.d/97bz1777525" 0 \
            "Install dracut plugin directory for testing"
        rlRun "install module-setup.sh relabel.sh /usr/lib/dracut/modules.d/97bz1777525" 0 \
            "Install dracut plugin for testing"
        rlRun "dracut -f" 0 "Rebuild the initramfs"
        rlRun "grubby --set-default /boot/vmlinuz-$(uname -r)" 0 \
            "Ensure the current booted kernel is the default"
        if command -v zipl >/dev/null; then
            rlRun "zipl" 0 "Run zipl"
        fi
    rlPhaseEnd

    rlPhaseStartSetup "Reboot"
        tmt-reboot
fi
        rlRun "uname -r" 0 "Kernel version after reboot"
    rlPhaseEnd

    rlPhaseStartTest "Test"
        rlLog "Test writing labels (BZ 1777525)"
        rlRun "ls -lZ /etc/testfile"
        rlRun "ls -lZ /etc/testfile | grep -qF ':etc_t:'" 0 \
            "Test that /etc/testfile is labeled correctly"

        rlLog "Test reading labels (BZ 1839819)"
        rlRun "cat /etc/labeldump"
        rlAssertNotDiffer "/etc/labeldump" labeldump-expected.txt
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f /etc/labeldump /etc/testfile" 0 "Remove test files"
        rlRun "rm -rf /usr/lib/dracut/modules.d/97bz1777525" 0 \
            "Remove the dracut plugin"
        rlRun "dracut -f" 0 "Rebuild the initramfs again"
        if command -v zipl >/dev/null; then
            rlRun "zipl" 0 "Run zipl"
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
