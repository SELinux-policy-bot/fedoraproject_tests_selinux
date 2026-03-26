#!/bin/bash

# Include beakerlib environment
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="policycoreutils-sandbox"
TEST_DIR="/tmp/mytest"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlRun "mkdir -p ${TEST_DIR}"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-144055 + RHEL-144041"
        # Create a file with malicious name 
        rlRun -s "seunshare -Z unconfined_u:unconfined_r:sandbox_x_t:s0 \
                -t ${TEST_DIR} \
                -- /bin/bash -c \"touch \\\"/tmp/' ; id -Z ; '\\\"\""
        rlRun "ls ${TEST_DIR} | grep '; id -Z ;' "
        # Trigger rsync which processes filenames
        rlRun -s "seunshare -Z unconfined_u:unconfined_r:sandbox_x_t:s0 \
                -t ${TEST_DIR} \
                -- /bin/bash -c \"touch \\\"/tmp/' ; id -Z ; '\\\"\" "
        rlAssertNotGrep "command not found" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf ${TEST_DIR}"
        rlRun "rm -f $rlRun_LOG"
    rlPhaseEnd

    rlJournalPrintText
rlJournalEnd
