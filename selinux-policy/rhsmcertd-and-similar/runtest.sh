#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k

. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted

        rlSESetTimestamp

        # Install required packages
        rlRun "dnf install -y python3-pip" 0
        rlFileBackup --clean /root/.local
    rlPhaseEnd

    rlPhaseStartTest "RHEL-106483"
        # Create /root/.local/lib/pythonX.Y/site-packages/ with gconf_home_t context
        rlRun "pip3 install --user abcd" 0 "pip install creates site-packages"
        SITE_PACKAGES=$(find /root/.local/lib -type d -name "site-packages" 2>/dev/null | head -1)
        rlAssertExists "${SITE_PACKAGES}"

        # Set SELinux to permissive to log AVCs without blocking
        rlRun "setenforce 0" 0 "Set SELinux to permissive mode"
        rlRun "runcon -t rhsmcertd_t -r system_r -u system_u -- /usr/bin/python3 -c 'import sys'" 0
    rlPhaseEnd

    rlPhaseStartCleanup
        # Restore backed up files (removes /root/.local if it didn't exist before)
        rlFileRestore
        rlSECheckAVC --ignore 'type=AVC .* entrypoint .*runcon .*:rhsmcertd_t:'
        # Restore SELinux to enforcing mode
        rlRun "setenforce 1" 0 "Restore SELinux to enforcing mode"

    rlPhaseEnd

rlJournalEnd
