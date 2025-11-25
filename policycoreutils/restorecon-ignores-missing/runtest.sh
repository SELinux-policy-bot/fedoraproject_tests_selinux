#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh

rlJournalStart
    rlPhaseStartSetup
        rlRun "rpm -qa | grep -e libselinux -e policycoreutils | sort"
        rlRun "man restorecon | col -b | grep -i 'ignore.*exist'"
        rlRun "mkdir -p tmp"
        OUTPUT_FILE=`mktemp`
    rlPhaseEnd

    rlPhaseStartTest "RHEL-110181 + RHEL-123884"
        rlRun "pushd tmp"
        rlLog "starting the creator process"
        ( while true ; do
            mkdir dir
            mkfifo fifo
            touch file
            chcon -t etc_t dir fifo file
            rm -rf dir fifo file
        done ) &
        CREATOR_PID=$!
        rlRun "popd"

        rlLog "starting the restorecon process"
        ( while true ; do restorecon -RFivv tmp ; done ) >& ${OUTPUT_FILE} &
        RESTORECON_PID=$!

        rlRun "sleep 30s"
        rlRun "kill ${CREATOR_PID}" 0,1
        rlRun "kill ${RESTORECON_PID}" 0,1
        rlRun "ls -l ${OUTPUT_FILE}"
        rlRun "grep -i -e 'no such file' -e 'not set context' ${OUTPUT_FILE}" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf tmp ${OUTPUT_FILE}"
    rlPhaseEnd
rlJournalEnd

