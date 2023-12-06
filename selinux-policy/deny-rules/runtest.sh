#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm libsepol
        rlAssertRpm libsemanage
        rlAssertRpm libselinux
        rlAssertRpm policycoreutils
        rlAssertRpm selinux-policy
        rlRun "setenforce 1"
        rlRun "sestatus"
    rlPhaseEnd

    rlPhaseStartTest "prevent the reading of a file"
        rlRun "stat /etc/shadow" 0
        rlRun "grep ^bin /etc/shadow" 0
        rlRun "echo -e '( deny unconfined_t shadow_t ( file ( getattr read )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun "stat /etc/shadow" 1
        rlRun "grep ^bin /etc/shadow" 2
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent the execution of a file"
        rlRun "dmesg >& /dev/null"
        rlRun "echo -e '( deny unconfined_t dmesg_exec_t ( file ( execute execute_no_trans )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun "dmesg" 126
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent removal of a file"
        if [ -f /etc/machine-id ] ; then
            rlRun "cp -a /etc/machine-id ."
        else
            rlRun "cp -a /run/machine-id ."
        fi
        rlRun "ls -Z ./machine-id"
        rlRun "echo -e '( deny unconfined_t machineid_t ( file ( unlink )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun "rm -f ./machine-id" 1,2
        rlRun "semodule -r testpolicy"
        rlRun "rm -f ./machine-id"
    rlPhaseEnd

    rlPhaseStartTest "prevent the search in a directory"
        rlRun "ls -lZR /etc/pki >& /dev/null"
        rlRun "echo -e '( deny unconfined_t cert_t ( dir ( search )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun "ls -lZR /etc/pki" 1
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent ptracing of processes"
        rlWatchdog "strace -p $$" 5
        rlRun "echo -e '( deny unconfined_t unconfined_t ( process ( ptrace )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "strace -p $$" 1
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent loading of kernel modules"
        if lsmod | grep -q dummy ; then
            rlRun "modprobe -r dummy"
        fi
        rlRun "echo -e '( deny unconfined_t unconfined_t ( system ( module_load module_request )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "modprobe dummy" 1
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "lsmod | grep dummy" 1
        rlRun "semodule -r testpolicy"
        rlRun "modprobe dummy"
        rlRun "lsmod | grep dummy"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd

