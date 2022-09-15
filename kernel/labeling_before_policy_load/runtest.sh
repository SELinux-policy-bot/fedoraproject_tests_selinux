#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
if [ $TMT_REBOOT_COUNT -lt 1 ]; then
    rlPhaseStartSetup "Setup"
        rlRun "uname -r" 0 "Kernel version before reboot"

        rlRun "install -d /usr/lib/dracut/modules.d/97bz1777525"
        rlRun "install module-setup.sh relabel.sh /usr/lib/dracut/modules.d/97bz1777525"
        rlRun "dracut --regenerate-all -f"
        if command -v zipl >/dev/null; then
            rlRun "zipl"
        fi
    rlPhaseEnd

    rlPhaseStartSetup "Reboot"
        tmt-reboot
fi
        rlRun "uname -r" 0 "Kernel version after reboot"
    rlPhaseEnd

    rlPhaseStartTest "Test"
        # Test writing labels (BZ 1777525)
        rlRun "ls -lZ /etc/testfile"
        rlRun "ls -lZ /etc/testfile | grep -qF ':etc_t:'" 0 \
            "/etc/testfile is labeled correctly"

        # Test reading labels (BZ 1839819)
        rlRun "cat /etc/labeldump"
        rlAssertNotDiffer "/etc/labeldump" labeldump-expected.txt
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f /etc/labeldump /etc/testfile"
        rlRun "rm -rf /usr/lib/dracut/modules.d/97bz1777525"
        rlRun "dracut --regenerate-all -f"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
