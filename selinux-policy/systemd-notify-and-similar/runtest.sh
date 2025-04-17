#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-notify-and-similar
#   Description: SELinux interferes with systemd-notify and related programs
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
SERVICE_PACKAGE="systemd"
#ALLOWED_USERS="guest_u xguest_u user_u staff_u sysadm_u unconfined_u"
ALLOWED_USERS="sysadm_u unconfined_u"
SYSTEMD_SYSTEM_SERVICE="/etc/systemd/system/local-notifier.service"
SYSTEMD_USER_SERVICE="/etc/systemd/user/local-notifier.service"
SYSTEMD_PAGER=""

rlJournalStart
    rlLog "If this test fails, please contact mmalik on IRC #selinux"
    rlLog "This test should fail if tested bugs are NOT fixed yet"
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

    rlPhaseStartTest "bz#1903305"
        if rlIsFedora "<35"; then
            rlSEMatchPathCon "/usr/bin/systemd-notify" "bin_t"
        else # Fedora up to 36 and RHEL
            rlSEMatchPathCon "/usr/bin/systemd-notify" "systemd_notify_exec_t"
        fi
        rlSESearchRule "allow init_t unconfined_t : fifo_file { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#1903305"
        rlRun "NOTIFY_SOCKET=/run/systemd/notify systemd-notify --ready"
        sleep 1
        rlRun "NOTIFY_SOCKET=/run/systemd/notify systemd-notify --ready"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- unconfined or user services use systemd-notify"
        rlRun "cp -f notifier.sh /usr/local/bin/"
        rlRun "cp -f local-notifier.service /etc/systemd/system/"
        rlRun "cp -f local-notifier.service /etc/systemd/user/"
        rlRun "restorecon -v /usr/local/bin/notifier.sh ${SYSTEMD_SYSTEM_SERVICE} ${SYSTEMD_USER_SERVICE}"
        rlRun "systemctl daemon-reload"
        # run the local-notifier service as a system service
        rlRun "systemctl start local-notifier"
        sleep 2
        rlRun "systemctl status local-notifier" 3
        # run the same service as a user service
        rlRun "setsebool ssh_sysadm_login on"
        CREATED_USERS=""
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -Rv /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost systemctl --no-pager --user start local-notifier"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost systemctl --no-pager --user status local-notifier"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost journalctl --no-pager --user -u local-notifier"
            CREATED_USERS="${USER_NAME} ${CREATED_USERS}"
        done
        rlRun "setsebool ssh_sysadm_login off"
        for USER_NAME in ${CREATED_USERS} ; do
            rlRun "userdel -rfZ ${USER_NAME}"
        done
        # cleanup
        rlRun "rm -f /usr/local/bin/notifier.sh ${SYSTEMD_SYSTEM_SERVICE} ${SYSTEMD_USER_SERVICE}"
        rlRun "systemctl daemon-reload"
    rlPhaseEnd

    if ! rlIsRHEL "<9.5" ; then
    rlPhaseStartTest "RHEL-25514 + RHEL-25605"
        rlSEMatchPathCon "/usr/bin/systemd-notify" "systemd_notify_exec_t"
        rlSEMatchPathCon "/run/systemd/notify" "init_var_run_t"
        rlSESearchRule "allow systemd_notify_t systemd_notify_t : capability { sys_admin } [ ]"
        rlSESearchRule "allow systemd_notify_t kernel_t : unix_dgram_socket { sendto } [ ]"

        rlRun "cp -f ./reproducer.service /etc/systemd/system/"
        rlRun "systemctl daemon-reload"
        rlRun "service reproducer start"
        rlRun -s "service reproducer status -l"
        rlRun "grep -i 'failed.*notify.*permission.*denied' $rlRun_LOG" 1
        rm -f $rlRun_LOG
        rlRun "rm -f /etc/systemd/system/reproducer.service"
        rlRun "systemctl daemon-reload"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

