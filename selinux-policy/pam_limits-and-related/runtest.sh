#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/pam_limits-and-related
#   Description: Does SELinux cooperate with pam_limits.so?
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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
SERVICE_PACKAGE="pam"
DENIED_USERS=${DENIED_USERS:-""}
ALLOWED_USERS=${ALLOWED_USERS:-"guest_u xguest_u user_u staff_u sysadm_u unconfined_u"}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlFileBackup /etc/shadow
        rlFileBackup /etc/security/limits.conf
        rlSEConfigureSSH

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 8 ; then
    rlPhaseStartTest "bz#1958819"
        rlSESearchRule "allow init_t guest_t : process2 { nnp_transition } [ ]"
        rlSESearchRule "allow init_t staff_t : process2 { nnp_transition } [ ]"
        rlSESearchRule "allow init_t sysadm_t : process2 { nnp_transition } [ ]"
        rlSESearchRule "allow init_t unconfined_t : process2 { nnp_transition } [ ]"
        rlSESearchRule "allow init_t user_t : process2 { nnp_transition } [ ]"
        rlSESearchRule "allow init_t xguest_t : process2 { nnp_transition } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- confined users"
        rlRun "setsebool ssh_sysadm_login on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "echo \"${USER_NAME} - nonewprivs 1\" >> /etc/security/limits.conf"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost id"
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

