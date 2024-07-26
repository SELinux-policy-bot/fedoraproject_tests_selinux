#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/pam_console-and-related
#   Description: Does SELinux cooperate with pam_console_apply and pam_console.so?
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
if rlIsRHEL 7 ; then
    DENIED_USERS=${DENIED_USERS:-"staff_u"}
    ALLOWED_USERS=${ALLOWED_USERS:-"guest_u xguest_u user_u sysadm_u unconfined_u"}
else
    DENIED_USERS=${DENIED_USERS:-""}
    ALLOWED_USERS=${ALLOWED_USERS:-"guest_u xguest_u user_u staff_u sysadm_u unconfined_u"}
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlFileBackup /etc/shadow
        rlSEConfigureSSH

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#204986"
        rlSEMatchPathCon "/usr/sbin/pam_console_apply" "pam_console_exec_t"
        rlSESearchRule "allow pam_console_t autofs_t : dir { read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#251104"
        rlSEMatchPathCon "/sbin/pam_console_apply" "pam_console_exec_t"
        rlSESearchRule "allow pam_console_t fs_t : filesystem { getattr } [ ]"
    rlPhaseEnd

    if ! rlIsRHEL 7 ; then
    rlPhaseStartTest "bz#1817690"
        rlSESearchRule "allow staff_t pam_console_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition staff_t pam_console_exec_t : process pam_console_t"
        rlSESearchRule "allow staff_t pam_console_t : process { transition } [ ]"
        rlRun "seinfo -rstaff_r -x | tr ' ' '\n' | grep pam_console_t"
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
            rlRun "restorecon -RvF /home/${USER_NAME}"
            # If a user logs in via console then a file of the same name as
            # the user appears in /run/console directory. The file exists as long
            # as the user is logged in. The file disappears after logout of the user.
            # Unfortunately, the use of SSH does not create such a file.
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/sbin/pam_console_apply -d"
            rlRun "ls -dZ /run/console"
            rlRun "ls -dZ /run/console | grep :pam_var_console_t"
            rlRun "ls -aZ /run/console"
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    if [ -f /usr/sbin/pam_console_apply ] ; then
    rlPhaseStartTest "real scenario -- runcon under root"
        rlRun "runcon system_u:system_r:initrc_t:s0 /bin/bash -c '/usr/sbin/pam_console_apply -r'"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlRun "service sshd restart"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

