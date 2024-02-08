#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "sestatus"
        rlRun "rpm -qa | grep -e audit -e libsepol -e libselinux -e libsemanage -e selinux-policy -e policycoreutils | sort"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "service auditd status -l"
        rlRun "ausearch -m avc -m selinux_err -i -ts boot" 1
        rlRun "dmesg | grep -i -e selinux -e type=1300 -e type=1400"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd

