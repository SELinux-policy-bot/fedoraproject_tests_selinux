#!/bin/bash
# vim: set dictionary=/usr/share/rhts-library/dictionary.vim cpt=.,w,b,u,t,i,k:
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bz481628-send-msg-to-dbus
#   Description: checks if dbus daemon is able to send message to hal daemon and vice versa
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2009 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="selinux-policy"
FILE_PATH="/bin/dbus-daemon"
FILE_CONTEXT="dbusd_exec_t"
SERVICE_PACKAGE="dbus"
if [ -f /usr/lib/systemd/system/dbus-broker.service ] ; then
    PROCESS_NAME="dbus-broker"
    SERVICE_NAME="dbus-broker"
else
    PROCESS_NAME="dbus-daemon"
    SERVICE_NAME="dbus"
fi
PROCESS_CONTEXT="system_dbusd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
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

    rlPhaseStartTest "bz#463267"
        if rlIsRHEL 5 ; then
            rlSEMatchPathCon "/lib/dbus-1/dbus-daemon-launch-helper" "system_dbusd_exec_t"
            rlSEMatchPathCon "/lib64/dbus-1/dbus-daemon-launch-helper" "system_dbusd_exec_t"
            rlSESearchRule "allow system_dbusd_t system_dbusd_exec_t : file { execute_no_trans }"
        else
            rlSEMatchPathCon "/lib/dbus-1/dbus-daemon-launch-helper" "dbusd_exec_t"
            rlSEMatchPathCon "/lib64/dbus-1/dbus-daemon-launch-helper" "dbusd_exec_t"
            rlSESearchRule "allow system_dbusd_t dbusd_exec_t : file { execute_no_trans }"
        fi
    rlPhaseEnd

    if rlSEDefined "hald_t" ; then
    rlPhaseStartTest "bz#481628"
        if rlIsRHEL 5 ; then
            rlSEMatchPathCon "/bin/dbus-daemon" "system_dbusd_exec_t"
        else
            rlSEMatchPathCon "/bin/dbus-daemon" "dbusd_exec_t"
        fi
        rlSESearchRule "allow system_dbusd_t hald_t : dbus { send_msg }"
        rlSESearchRule "allow hald_t system_dbusd_t : dbus { send_msg }"
        rlSESearchRule "allow system_dbusd_t unconfined_t : dbus { send_msg }"
        rlSESearchRule "allow unconfined_t system_dbusd_t : dbus { send_msg }"
        if rlIsRHEL 5 ; then
            rlSESearchRule "allow initrc_t system_dbusd_exec_t : file { getattr open read execute }"
            rlSESearchRule "type_transition initrc_t system_dbusd_exec_t : process system_dbusd_t"
        else
            rlSESearchRule "allow initrc_t dbusd_exec_t : file { getattr open read execute }"
            rlSESearchRule "type_transition initrc_t dbusd_exec_t : process system_dbusd_t"
        fi
        rlSESearchRule "allow initrc_t system_dbusd_t : process { transition }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1546721"
        rlSEMatchPathCon "/usr/libexec/dbus-1/dbus-daemon-launch-helper" "dbusd_exec_t"
    rlPhaseEnd

    rlPhaseStartTest "bz#1614236"
        rlSEMatchPathCon "/usr/bin/dbus-daemon" "dbusd_exec_t"
        rlSEMatchPathCon "/dev/nvme0n1p1" "nvme_device_t"
        rlSESearchRule "allow system_dbusd_t nvme_device_t : blk_file { read } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlSEService "nopassword" ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "reload status" 1
    rlPhaseEnd

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1688671"
        rlSEMatchPathCon "/run/user/1000" "user_tmp_t"
        if [ -f /usr/lib/systemd/system/dbus-broker.service ] ; then
                rlSEMatchPathCon "/run/user/1000/dbus" "session_dbusd_tmp_t"
                rlSEMatchPathCon "/run/user/1000/dbus/services" "session_dbusd_tmp_t"
	else
                rlSEMatchPathCon "/run/user/1000/dbus-1" "session_dbusd_tmp_t"
                rlSEMatchPathCon "/run/user/1000/dbus-1/services" "session_dbusd_tmp_t"
        fi
        rlSESearchRule "allow init_t session_dbusd_tmp_t : dir { read } [ ]"
        rlSESearchRule "type_transition staff_dbusd_t user_tmp_t : dir session_dbusd_tmp_t"
        rlSESearchRule "type_transition sysadm_dbusd_t user_tmp_t : dir session_dbusd_tmp_t"
        rlSESearchRule "type_transition unconfined_dbusd_t user_tmp_t : dir session_dbusd_tmp_t"
        rlSESearchRule "type_transition user_dbusd_t user_tmp_t : dir session_dbusd_tmp_t"
        rlSESearchRule "type_transition xguest_dbusd_t user_tmp_t : dir session_dbusd_tmp_t"
    rlPhaseEnd

    rlPhaseStartTest "bz#1727887 + bz#1754476"
        rlSESearchRule "allow guest_t init_t : process { signal } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- user session service"
        rlRun "setsebool ssh_sysadm_login on"
        rlRun "setsebool selinuxuser_tcp_server on"
        CREATED_USERS=""
        # TODO: guest_u, xguest_u cannot successfully run systemctl
        for SELINUX_USER in user_u staff_u sysadm_u unconfined_u ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -RvF /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/bin/systemctl --user --no-pager status dbus"
            rlRun "rm -f files.txt"
            USER_ID=`id -u ${USER_NAME}`
            ( sleep 3 ; ls -RZ /run/user/${USER_ID} > files.txt ) &
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/bin/systemctl --user --no-pager start dbus"
            if ! [ -f /usr/lib/systemd/system/dbus-broker.service ] ; then
                rlRun "grep \"${SELINUX_USER}:object_r:session_dbusd_tmp_t:.* dbus-1\" files.txt"
                rlRun "grep \"${SELINUX_USER}:object_r:session_dbusd_tmp_t:.* services\" files.txt"
            fi
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost /usr/bin/busctl --user --no-pager"
            CREATED_USERS="${USER_NAME} ${CREATED_USERS}"
        done
        for USER_NAME in ${CREATED_USERS} ; do
            rlRun "userdel -rfZ ${USER_NAME}"
        done
        rlRun "setsebool selinuxuser_tcp_server off"
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC --ignore 'type=AVC .* create .*systemd .*:user_t:.*:user_tmp_t:.*tclass=dir'
        rm -f files.txt

        rlFileRestore
        rlRun "service sshd restart"
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

