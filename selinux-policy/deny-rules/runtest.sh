#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

USER_CONTEXT=${USER_CONTEXT:-"sysadm_u:sysadm_r:sysadm_t"}
SELINUX_USER=`echo ${USER_CONTEXT} | cut -d : -f 1`
USER_ROLE=`echo ${USER_CONTEXT} | cut -d : -f 2`
USER_TYPE=`echo ${USER_CONTEXT} | cut -d : -f 3`
USER_NAME="user${RANDOM}"
USER_SECRET="S3krET${RANDOM}"

rlJournalStart
    CUR_VERSION=`rpm -q --qf "%{version}" policycoreutils | head -n 1`
    if rlTestVersion ${CUR_VERSION} '<' 3.6 ; then
        rlLog "The installed SELinux userspace does NOT support deny rules."
        rlLog "The automated test is NOT relevant for this environment."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlAssertRpm libsepol
        rlAssertRpm libsemanage
        rlAssertRpm libselinux
        rlAssertRpm policycoreutils
        rlAssertRpm selinux-policy
        if ! rpm -q strace ; then
            rlRun "yum -y install strace" 0-255
        fi

        rlRun "setenforce 1"
        rlRun "sestatus"
        rlRun "useradd -o -u 0 -g 0 -Z ${SELINUX_USER} ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "setsebool ssh_sysadm_login on"

        rlFileBackup /etc/ssh/sshd_config
        rlRun "sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config"
        rlRun "sed -i 's/^.*PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config"
        if [ -d /etc/ssh/sshd_config.d ] ; then
            rlRun "echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/001-enable-password.conf"
        fi
        rlRun "service sshd restart"
    rlPhaseEnd

    rlPhaseStartTest "prevent the reading of a file"
        rlRun "stat /etc/shadow" 0
        rlRun "grep ^bin /etc/shadow" 0
        rlRun "echo -e '( deny ${USER_TYPE} shadow_t ( file ( getattr read )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost stat /etc/shadow"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost grep ^bin /etc/shadow"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent the execution of a file"
        rlRun "dmesg >& /dev/null"
        rlRun "echo -e '( deny ${USER_TYPE} dmesg_exec_t ( file ( execute execute_no_trans )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost dmesg"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent removal of a file"
        if [ -f /etc/machine-id ] ; then
            rlRun "cp -a /etc/machine-id /home/${USER_NAME}/"
        else
            rlRun "cp -a /run/machine-id /home/${USER_NAME}/"
        fi
        rlRun "ls -Z /home/${USER_NAME}/machine-id"
        rlRun "echo -e '( deny ${USER_TYPE} machineid_t ( file ( unlink )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost rm -f /home/${USER_NAME}/machine-id"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "semodule -r testpolicy"
        rlRun "rm -f /home/${USER_NAME}/machine-id"
    rlPhaseEnd

    rlPhaseStartTest "prevent the search in a directory"
        rlRun "ls -lZR /etc/pki >& /dev/null"
        rlRun "echo -e '( deny ${USER_TYPE} cert_t ( dir ( search )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost ls -lZR /etc/pki"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent ptracing of processes"
        rlWatchdog "strace -p $$" 5
        rlRun "echo -e '( deny ${USER_TYPE} ${USER_TYPE} ( process ( ptrace )))' > testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost strace -p $$"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "semodule -r testpolicy"
    rlPhaseEnd

    rlPhaseStartTest "prevent loading of kernel modules"
        if lsmod | grep -q dummy ; then
            rlRun "modprobe -r dummy"
        fi
        rlRun "echo -e '( deny ${USER_TYPE} ${USER_TYPE} ( system ( module_load module_request )))' > testpolicy.cil"
        rlRun "echo -e '( deny kmod_t kmod_t ( system ( module_load module_request )))' >> testpolicy.cil"
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost modprobe dummy"
        rlRun "grep -i 'permission denied' $rlRun_LOG"
        rm -f $rlRun_LOG
        rlRun "lsmod | grep dummy" 1
        rlRun "semodule -r testpolicy"
        rlRun "modprobe dummy"
        rlRun "lsmod | grep dummy"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "setsebool ssh_sysadm_login off"
        rlRun "userdel -rfZ ${USER_NAME}"
        rlFileRestore
        if [ -d /etc/ssh/sshd_config.d ] ; then
            rlRun "rm -f /etc/ssh/sshd_config.d/001-enable-password.conf"
        fi
        rlRun "service sshd restart"
    rlPhaseEnd
rlJournalEnd

