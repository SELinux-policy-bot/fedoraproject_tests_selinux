#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm selinux-policy
        rlAssertRpm policycoreutils-restorecond
        rlServiceStop restorecond
        rlFileBackup /etc/selinux/restorecond.conf
        # add locations which are in fact symlinks
        rlRun "echo -en '\n/bin/*\n/sbin/*\n/lib/*\n/lib64/*\n' >> /etc/selinux/restorecond.conf"
    rlPhaseEnd

    if ! rlIsRHEL "<9.4" ; then
    rlPhaseStartTest "RHEL-5032"
        rlRun "service restorecond start"
        rlRun "service restorecond status"
        rlRun -s "restorecon -Rv /usr/bin /usr/sbin /usr/lib /usr/lib64"
        rlRun "grep -i 'relabeled.*from.*to' $rlRun_LOG" 1
        rm -f $rlRun_LOG
        rlRun "service restorecond stop"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rlFileRestore
        rlServiceRestore restorecond
    rlPhaseEnd
rlJournalEnd

