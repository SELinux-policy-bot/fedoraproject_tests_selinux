#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
SERVICE_PACKAGE="systemd-journal-remote"
SERVICE_NAME="systemd-journal-upload"
PROCESS_NAME="systemd-journal-upload"
PROCESS_CONTEXT="systemd_journal_upload_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-57774"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-journal-upload" "systemd_journal_upload_exec_t"
        rlSEMatchPathCon "/run/systemd/journal-upload.conf.d" "systemd_conf_t"
        rlSESearchRule "allow systemd_journal_upload_t systemd_conf_t : dir { read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- RHEL-57774"
        rlRun "mkdir -pZ /run/systemd/journal-upload.conf.d"
        rlRun "echo -e '[Upload]\nURL=http://localhost/\n' > /run/systemd/journal-upload.conf.d/test.conf"
        rlRun "restorecon -Rv /run/systemd"
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rm -f /run/systemd/journal-upload.conf.d/test.conf
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalEnd

