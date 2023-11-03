#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "rpm -qa | grep policycoreutils"
    rlPhaseEnd

    rlPhaseStartTest "bz#1416372"
        rlRun -s "sepolicy manpage -a"
        rlRun "grep -i -e invalid -e error -e traceback ${rlRun_LOG}" 1
        rm -f ${rlRun_LOG}
        rlRun -s "sepolicy manpage -d crond_t"
        rlRun "grep -i -e invalid -e error -e traceback ${rlRun_LOG}" 1
        rm -f ${rlRun_LOG}
    rlPhaseEnd

    rlPhaseStartTest "sepolicy manpage --web, bz#1854639 + bz#1989840"
        rlRun "sepolicy manpage --web -d zebra_t"
        if rlIsRHEL 7 8 || rlIsCentOS 7 8 ; then
            rlRun "ls -l /tmp/*release*" 0 "Html file with OS name exists."
            rlRun "cat /tmp/*release* > /tmp/testfile"
        else
            rlRun "ls -l /tmp/index.html" 0 "HTML file exists"
            rlRun "cat /tmp/index.html > /tmp/testfile"
        fi
        rlAssertGrep "href=zebra.html" "/tmp/testfile"
        rlRun "ls -l /tmp/zebra.html"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f /tmp/zebra* /tmp/index.html /tmp/*release*"
    rlPhaseEnd
rlJournalEnd

