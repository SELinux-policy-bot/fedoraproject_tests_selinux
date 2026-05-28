#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k

. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
INSTALL_OPTION=""
if dnf --help | grep -q use-host-config ; then
    INSTALL_OPTION="${INSTALL_OPTION} --use-host-config"
fi
if dnf install --help | grep -q skip-broken ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-broken"
fi
if dnf install --help | grep -q skip-unavailable ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-unavailable"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlAssertRpm systemd-container
        rlSESetEnforce
        rlSESetTimestamp
    rlPhaseEnd

    rlPhaseStartTest "RHEL-139983"
        rlRun "mkdir -p /var/lib/machines/foo"
        rlRun "dnf install -y --installroot /var/lib/machines/foo --nogpgcheck systemd-udev ${INSTALL_OPTION}"
        
        rlRun "systemd-nspawn -bD /var/lib/machines/foo >/dev/null 2>&1 &"
        sleep 2
        rlRun -s  "systemd-run -q --wait --pipe -M foo ls -lZ /run/systemd/coredump 2>&1"
        rlAssertNotGrep "user_tmp_t" "$rlRun_LOG" -i
        # Crash should not cause coredump avc
        rlRun "systemd-run -q --wait --pipe -M foo bash -xc 'kill -SEGV \$\$\$\$'" 1-255
        rlRun "machinectl terminate foo"
        sleep 2
        rlRun "rm -f /run/systemd/machines/foo"
        sleep 2

        # Same scenario but container started with machinectl
        rlRun "machinectl start foo"
        sleep 2
        rlRun -s  "systemd-run -q --wait --pipe -M foo ls -lZ /run/systemd/coredump 2>&1"
        rlAssertNotGrep "tmpfs_t" "$rlRun_LOG" -i
        rlRun "systemd-run -q --wait --pipe -M foo bash -xc 'kill -SEGV \$\$\$\$'" 1-255
        rlRun "machinectl terminate foo"
        sleep 2
        rlRun "rm -f /run/systemd/machines/foo"
        rlRun "rm -rf /var/lib/machines/foo"
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
