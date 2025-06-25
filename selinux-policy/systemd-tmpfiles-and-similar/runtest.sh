#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-tmpfiles-and-similar
#   Description: SELinux interferes with systemd-tmpfiles and related programs
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

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
SERVICE_PACKAGE="systemd"
ALLOWED_USERS="staff_u sysadm_u unconfined_u"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlSEConfigureSSH

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-40374 + RHEL-44191"
        rlSEMatchPathCon "/usr/bin/systemd-tmpfiles" "systemd_tmpfiles_exec_t"
        if rlSEDefined "staff_t" ; then
            rlSESearchRule "allow staff_t systemd_tmpfiles_exec_t : file { getattr open read map execute execute_no_trans } [ ]"
        fi
        rlRun "setsebool ssh_sysadm_login on"
        CREATED_USERS=""
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -Rv /home/${USER_NAME}"
            rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost systemctl --no-pager --user status systemd-tmpfiles-setup.service"
            rlRun "grep -i failed $rlRun_LOG" 1
            rm -f $rlRun_LOG
            rlRun -s "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost systemctl --no-pager --user --failed"
            rlRun "grep '0 loaded units listed' $rlRun_LOG"
            rm -f $rlRun_LOG
            CREATED_USERS="${USER_NAME} ${CREATED_USERS}"
        done
        rlRun "setsebool ssh_sysadm_login off"
        for USER_NAME in ${CREATED_USERS} ; do
            rlRun "userdel -rfZ ${USER_NAME}"
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

