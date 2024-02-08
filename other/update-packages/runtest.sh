#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "rpm -qa | grep -e audit -e libsepol -e libselinux -e libsemanage -e selinux-policy -e policycoreutils | sort"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "dnf clean all"
        rlRun "dnf -y update --skip-broken --allowerasing"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rpm -qa | grep -e audit -e libsepol -e libselinux -e libsemanage -e selinux-policy -e policycoreutils | sort"
    rlPhaseEnd
rlJournalEnd

