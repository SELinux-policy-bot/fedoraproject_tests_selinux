#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/sudo-and-dnf
#   Description: SELinux interferes with the dnf command executed via sudo
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm dnf
        rlAssertRpm sudo

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#2233065 + RHEL-9947"
        rlSEConfigureSSH
        rlRun "setsebool ssh_sysadm_login on"
        USER_NAME="sysadm${RANDOM}"
        USER_SECRET="S3kr3t${RANDOM}"
        rlRun "useradd -Z sysadm_u ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "echo \"${USER_NAME} ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/dnf-test"
        rlRun "ls -dlZ /var/lib/rpm"

        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost sudo dnf clean all"
        rlRun "grep -i 'rpmdb open failed' $rlRun_LOG" 1
        rm -f $rlRun_LOG
        rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost sudo dnf update -y"
        rlRun "grep -i 'rpmdb open failed' $rlRun_LOG" 1
        rm -f $rlRun_LOG

        rlRun "rm -f /etc/sudoers.d/dnf-test"
        rlRun "userdel -rfZ ${USER_NAME}"
        rlRun "setsebool ssh_sysadm_login off"
        rlFileRestore
        rlRun "service sshd restart"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

