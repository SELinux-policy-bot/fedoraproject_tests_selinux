#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/pam_timestamp-and-related
#   Description: Does SELinux cooperate with pam_timestamp_check and pam_timestamp.so?
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
SERVICE_PACKAGE="pam"
DENIED_USERS=${DENIED_USERS:-"guest_u xguest_u"}
ALLOWED_USERS=${ALLOWED_USERS:-"staff_u user_u sysadm_u unconfined_u"}
TIMESTAMP_DIR=${TIMESTAMP_DIR:-"/run/pam_timestamp"}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlFileBackup /etc/shadow
        rlFileBackup ${TIMESTAMP_DIR}/_pam_timestamp_key

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL "<8.3" ; then
    rlPhaseStartTest "bz#1791957"
        rlSEMatchPathCon "/run" "var_run_t"
        rlSEMatchPathCon "${TIMESTAMP_DIR}" "pam_var_run_t"
        rlSEMatchPathCon "/usr/sbin/pam_timestamp_check" "pam_timestamp_exec_t"
        rlSESearchRule "allow sshd_t var_run_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition sshd_t var_run_t : dir pam_var_run_t"
        rlSESearchRule "allow sshd_t pam_var_run_t : dir { create } [ ]"
        # sed is needed for pam versions before
        # https://github.com/linux-pam/linux-pam/commit/9b62f2ed3be1731581ad8f4b7e5cefd8fd030085
        rlRun "strings /usr/sbin/pam_timestamp_check | sed \"s|//*|/|g\" | grep ${TIMESTAMP_DIR}"
        rlRun "strings /usr/lib64/security/pam_timestamp.so | sed \"s|//*|/|g\" | grep ${TIMESTAMP_DIR}"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- confined users"
        rlRun "setsebool ssh_sysadm_login on"
        rlRun "mkdir -p ${TIMESTAMP_DIR}"
        rlRun "touch ${TIMESTAMP_DIR}/_pam_timestamp_key"
        rlRun "restorecon -RvF ${TIMESTAMP_DIR}"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/pam_timestamp_check"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/pam_timestamp_check -k"
            ( sleep 5 ; ps -efZ > /home/${USER_NAME}/processes.txt ; killall pam_timestamp_check ) &
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/pam_timestamp_check -d"
            if [[ ${SELINUX_USER} == "unconfined_u" ]] ; then
                rlRun "grep \"${SELINUX_USER}:${SELINUX_USER/_u/_r}:${SELINUX_USER/_u/_t}:.*pam_timestamp_check\" /home/${USER_NAME}/processes.txt"
            else
                rlRun "grep \"${SELINUX_USER}:${SELINUX_USER/_u/_r}:pam_timestamp_t:.*pam_timestamp_check\" /home/${USER_NAME}/processes.txt"
            fi
            rlRun "userdel -rfZ ${USER_NAME}"
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlRun "rm -f ${TIMESTAMP_DIR}/_pam_timestamp_key"
        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

