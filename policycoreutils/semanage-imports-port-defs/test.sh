#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm policycoreutils
        rlRun "rpm -qf /usr/sbin/semanage"
        rlRun "semanage port -a -t http_cache_port_t -r s0 -p tcp 3024"
    rlPhaseEnd

    rlPhaseStartTest "bz#2063353 + bz#2108174"
        rlRun "semanage port -E"
        rlRun "echo -e 'port -D\nport -a -t http_cache_port_t -r s0 -p tcp 3024'  | semanage import"
        rlRun "semanage port -E"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semanage port -d -t http_cache_port_t -r s0 -p tcp 3024"
    rlPhaseEnd
rlJournalEnd

