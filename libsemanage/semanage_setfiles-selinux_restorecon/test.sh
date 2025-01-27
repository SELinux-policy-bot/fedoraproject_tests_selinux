#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "set -o pipefail"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "mkdir -p $tmp/test/subtest | cut -d ' ' -f 1"
        rlRun "ls -Zd $tmp/test $tmp/test/subtest | cut -d ' ' -f 1"

        rlRun "python3 update_context.py $tmp/test pki_tomcat_etc_rw_t"
        LABEL=system_u:object_r:pki_tomcat_etc_rw_t:s0
        LABEL_TEST=$(ls -Zd $tmp/test | cut -d ' ' -f 1)
        LABEL_SUBTEST=$(ls -Zd $tmp/test/subtest | cut -d ' ' -f 1)
        rlRun "ls -Zd $tmp/test $tmp/test/subtest"
        rlAssertEquals "Is $tmp/test $LABEL?" "$LABEL_TEST" "$LABEL"
        rlAssertEquals "Is $tmp/test/subtest $LABEL?" "$LABEL_SUBTEST" "$LABEL"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semanage fcontext -D"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
