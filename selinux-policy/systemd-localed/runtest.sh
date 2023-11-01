#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
SERVICE_PACKAGE="systemd"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop systemd-localed
        rlFileBackup --clean --missing-ok /etc/X11/xorg.conf.d

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#2240159 + RHEL-16715 + RHEL-16716"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-localed" "systemd_localed_exec_t"
        rlSEMatchPathCon "/etc/X11/xorg.conf.d" "xserver_etc_t"
        rlSESearchRule "allow systemd_localed_t xserver_etc_t : dir { create } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#2240159"
        if [ -d /etc/X11/xorg.conf.d ] ; then
            rlRun "rpm -qf /etc/X11/xorg.conf.d" 0,1
            rlRun "rm -rf /etc/X11/xorg.conf.d"
        fi
        rlRun "service systemd-localed start"
        rlRun "service systemd-localed status"
        rlRun "localectl set-x11-keymap us"
        rlRun "ls -lZ /etc/X11/xorg.conf.d"
        rlRun "service systemd-localed stop"
        rlRun "service systemd-localed status" 3
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore systemd-localed
    rlPhaseEnd
rlJournalEnd

