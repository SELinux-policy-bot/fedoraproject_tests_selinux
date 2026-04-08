#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh

rlJournalStart
    rlPhaseStartSetup
        rlRun "rpm -qa | grep policycoreutils | sort"
        rlServiceStop restorecond
        rlRun "rm -f /run/restorecond.pid"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-142541 + RHEL-165247"
        rlRun "grep ^Type=simple /usr/lib/systemd/system/restorecond.service"
        rlRun "touch /run/restorecond.pid"
        rlRun "ls -lZ /run/restorecond.pid"
        rlRun "ls -lZ /run/restorecond.pid | grep :var_run_t"
        rlRun "systemctl start restorecond.service"
        sleep 2
        rlRun -s "systemctl status restorecond.service -l"
        rlRun "grep -i -e '/run/restorecond.pid' -e 'failed.*timeout' $rlRun_LOG" 1
        rm -f $rlRun_LOG
        rlRun "systemctl restart restorecond.service"
        sleep 2
        rlRun -s "systemctl status restorecond.service -l"
        rlRun "grep -i -e '/run/restorecond.pid' -e 'failed.*timeout' $rlRun_LOG" 1
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f /run/restorecond.pid"
        rlServiceRestore restorecond
    rlPhaseEnd
rlJournalEnd

