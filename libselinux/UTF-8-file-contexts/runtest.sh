#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libselinux/Sanity/UTF-8-file-contexts
#   Description: Verify UTF-8 paths in local file contexts
#   Author: Petr Lautrbach <lautrbach@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. /usr/share/beakerlib/beakerlib.sh || exit 1

FCONTEXT_TYPE="etc_t"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm libselinux-utils
        rlAssertRpm policycoreutils
        rlAssertRpm policycoreutils-python-utils
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "UTF8_PATH='${TmpDir}/Öffentlich'"
        rlRun "mkdir -p '${UTF8_PATH}/subdir'"
        rlRun "touch '${UTF8_PATH}/subdir/file'"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "semanage fcontext -a -t ${FCONTEXT_TYPE} '${UTF8_PATH}(/.*)?'"

        rlRun -s "semanage fcontext -l -C"
        rlAssertGrep "${UTF8_PATH}" "$rlRun_LOG"

        rlRun -s "restorecon -RFvv '${UTF8_PATH}'"
        rlAssertNotGrep "Non-ASCII characters found" "$rlRun_LOG"

        rlRun -s "matchpathcon '${UTF8_PATH}'"
        rlAssertGrep ":${FCONTEXT_TYPE}:" "$rlRun_LOG"

        rlRun -s "matchpathcon '${UTF8_PATH}/subdir/file'"
        rlAssertGrep ":${FCONTEXT_TYPE}:" "$rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semanage fcontext -d '${UTF8_PATH}(/.*)?'"
    rlPhaseEnd

    # Cleanup phase: Remove test directory
    rlPhaseStartCleanup
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
        
rlJournalPrintText
rlJournalEnd
