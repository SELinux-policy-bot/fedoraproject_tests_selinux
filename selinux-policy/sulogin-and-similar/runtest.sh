#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm selinux-policy
        rlAssertRpm selinux-policy-targeted
        rlAssertRpm systemd

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 8 9 && ! rlIsCentOS 8 9 ; then
    rlPhaseStartTest "bz#2265391"
        rlSEMatchPathCon "/usr/sbin/sulogin" "sulogin_exec_t"
        rlSESearchRule "dontaudit sulogin_t sulogin_t : capability2 { checkpoint_restore } [ ]"
        rlSESearchRule "allow sulogin_t tty_device_t : chr_file { relabelfrom relabelto } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/rescue.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "grep ExecStart= /usr/lib/systemd/system/rescue.service"
        rlRun "strings /usr/lib/systemd/systemd-sulogin-shell | grep bin/sulogin"
        rlRun "service rescue start"
        sleep 2
        rlRun "service rescue status"
        rlRun "service rescue stop"
        sleep 2
        rlRun "service rescue status" 3
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalEnd

