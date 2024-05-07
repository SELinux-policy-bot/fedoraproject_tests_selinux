#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/setools/Sanity/apol
#   Description: basic apol testing
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "rpm -qa | grep setools"
        for POLICY_KIND in mls targeted ; do
            rlAssertRpm selinux-policy-${POLICY_KIND}
        done
        rlFileBackup /etc/tigervnc/vncserver.users
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- RHEL-29967"
        USER_NAME="toor"
        USER_SECRET="S3kr3t${RANDOM}"
        if ! grep -q ":10=${USER_NAME}" /etc/tigervnc/vncserver.users ; then
            rlRun "echo -en '\n:10=${USER_NAME}\n' >> /etc/tigervnc/vncserver.users"
        fi
        rlRun "useradd -o -u 0 -g 0 ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "mkdir -p /home/${USER_NAME}/.config"
        rlRun "mkdir -p /home/${USER_NAME}/.vnc"
        rlRun "echo ${USER_SECRET} | vncpasswd -f > /home/${USER_NAME}/.vnc/passwd"
        rlRun "chmod go= /home/${USER_NAME}/.vnc/passwd"
        rlRun "ls -l /home/${USER_NAME}/.vnc/"
        rlRun "restorecon -RvF /home/${USER_NAME}"
        rlRun "systemctl enable vncserver@:10.service"
        rlRun "systemctl start vncserver@:10.service"
        sleep 15
        rlRun "cat /home/${USER_NAME}/.vnc/*.log"
        rlRun "systemctl status vncserver@:10.service"
        for POLICY_KIND in mls targeted ; do
            rlRun "cp /etc/selinux/${POLICY_KIND}/policy/policy.* /home/${USER_NAME}/policy.${POLICY_KIND}"
            rlWatchdog "DISPLAY=:10 apol -v /home/${USER_NAME}/policy.${POLICY_KIND} >& output.txt" 30
            rlRun "grep -i 'success.*open.*permission map' output.txt"
            rlRun "grep -i 'success.*open.*policy' output.txt"
            rlRun "grep -i -e traceback -e error output.txt" 1
        done
        rlRun "systemctl stop vncserver@:10.service"
        rlRun "systemctl status vncserver@:10.service" 3
        rlRun "systemctl disable vncserver@:10.service"
        sleep 15
        rlRun "userdel -rfZ ${USER_NAME}"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

