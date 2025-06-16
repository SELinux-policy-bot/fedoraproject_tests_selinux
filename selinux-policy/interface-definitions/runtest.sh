#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm selinux-policy
        rlAssertRpm policycoreutils
    rlPhaseEnd

    if ! rlIsRHEL 9 && ! rlIsCentOS 9 ; then
    # the bug is fixed on RHEL-8 but it was auto-closed on RHEL-9
    rlPhaseStartTest "RHEL-2616 + RHEL-16185"
        rlRun "sepolgen-ifgen -v -d 2>/dev/null | sort | uniq > output.txt"
        rlRun "grep -i missing output.txt" 1
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#2254169 + bz#2254206 + bz#2277925"
        rlRun "yum -y reinstall selinux-policy-devel >& output.txt"
        rlRun "grep -i illegal output.txt" 1
        rlRun "sepolgen-ifgen --verbose >& output.txt"
        rlRun "grep -i illegal output.txt" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        rm -f output.txt
    rlPhaseEnd
rlJournalEnd

