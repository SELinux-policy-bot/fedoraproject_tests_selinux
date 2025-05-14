#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "set -o pipefail"
        rlRun "source /etc/selinux/config"
        rlRun "ETC_RW_T_LABEL=\"$(seinfo -t | grep etc_rw_t | head -1 | awk '{$1=$1};1')\""
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "mkdir -p $tmp/test/subtest | cut -d ' ' -f 1"
        rlRun "ls -Zd $tmp/test $tmp/test/subtest | cut -d ' ' -f 1"

        rlRun "python3 update_context.py $tmp/test ${ETC_RW_T_LABEL} ${SELINUXTYPE}"
        LABEL="system_u:object_r:${ETC_RW_T_LABEL}:s0"
        LABEL_TEST=$(ls -Zd $tmp/test | cut -d ' ' -f 1)
        LABEL_SUBTEST=$(ls -Zd $tmp/test/subtest | cut -d ' ' -f 1)
        rlRun "ls -Zd $tmp/test $tmp/test/subtest"
        rlAssertEquals "Is $tmp/test $LABEL?" "$LABEL_TEST" "$LABEL"
        rlAssertEquals "Is $tmp/test/subtest $LABEL?" "$LABEL_SUBTEST" "$LABEL"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semanage fcontext -D"
        rlRun "rm -rf $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
