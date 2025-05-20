#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm setroubleshoot-server
    rlPhaseEnd

    rlPhaseStartTest "bz#2365614"
        rlRun "rpm -q --requires setroubleshoot-server | grep initscripts" 1
        rlRun "rpm -q --scripts setroubleshoot-server | grep service" 1
        rlRun "rpm -q --scripts setroubleshoot-server | grep 'auditctl.*reload'"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd
