#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "sestatus"
        rlRun "rpm -qa | grep -e libsepol -e libselinux -e libsemanage -e selinux-policy -e policycoreutils -e setools | sort"
    rlPhaseEnd

    rlPhaseStartTest "libselinux - RHEL-118812"
        rlRun -s "python3 -c \"import warnings ; warnings.simplefilter('always') ; import selinux\""
        rlRun "grep -i deprecation $rlRun_LOG" 1
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "libsemanage - RHEL-138405"
        rlRun -s "python3 -c \"import warnings ; warnings.simplefilter('always') ; import semanage\""
        rlRun "grep -i deprecation $rlRun_LOG" 1
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "policycoreutils - RHEL-138406"
        rlRun -s "python3 -c \"import warnings ; warnings.simplefilter('always') ; import seobject ; import sepolgen ; import sepolicy\""
        rlRun "grep -i deprecation $rlRun_LOG" 1
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "setools"
        rlRun -s "python3 -c \"import warnings ; warnings.simplefilter('always') ; import setools\""
        rlRun "grep -i deprecation $rlRun_LOG" 1
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd

