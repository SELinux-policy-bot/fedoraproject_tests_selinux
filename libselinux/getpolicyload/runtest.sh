#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm libselinux
        rlAssertRpm libselinux-utils
        rlAssertRpm policycoreutils
        rlRun "sestatus"
    rlPhaseEnd

    rlPhaseStartTest
        for CMD in "semodule -R" "semodule -B" "semodule --refresh" "load_policy" "load_policy -i" ; do
            BEFORE=`getpolicyload`
            rlRun "getpolicyload"
            rlRun "${CMD}"
            AFTER=`getpolicyload`
            rlRun "getpolicyload"
            rlAssertGreater "the number of policy loads increased" ${AFTER} ${BEFORE}
        done
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd

