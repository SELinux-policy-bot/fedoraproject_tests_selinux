#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/cockpit-ws-and-similar
#   Description: SELinux interferes with cockpit-ws and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/libexec/cockpit-ws"
FILE_CONTEXT="cockpit_ws_exec_t"
SERVICE_PACKAGE="cockpit-ws"
SERVICE_NAME="cockpit"
if grep "cockpit-tls" /usr/lib/systemd/system/cockpit.service; then
    PROCESS_NAME="cockpit-tls"
else
    PROCESS_NAME="cockpit-ws"
fi
PROCESS_CONTEXT="cockpit_ws_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1100808"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1214223"
        rlSEMatchPathCon "/usr/libexec/cockpit-session" "cockpit_session_exec_t"
        rlSEMatchPathCon "/var/tmp" "tmp_t"
        rlSESearchRule "allow cockpit_session_t tmp_t : dir { read write add_name remove_name getattr open search } [ ]"
        rlSESearchRule "type_transition cockpit_session_t tmp_t : file cockpit_tmp_t"
        rlSESearchRule "allow cockpit_session_t cockpit_tmp_t : file { create write open unlink } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1279429 + bz#1283955"
        rlSEMatchPathCon "/usr/libexec/cockpit-ws" "cockpit_ws_exec_t"
        rlSEMatchPathCon "/tmp" "tmp_t"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/cockpit-ws" "cockpit_var_run_t"
        rlSESearchRule "allow cockpit_ws_t var_run_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition cockpit_ws_t var_run_t : dir cockpit_var_run_t [ ]"
        rlSESearchRule "allow cockpit_ws_t cockpit_var_run_t : dir { create } [ ]"
        rlSESearchRule "allow cockpit_ws_t tmp_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition cockpit_ws_t tmp_t : dir cockpit_tmp_t [ ]"
        rlSESearchRule "type_transition cockpit_ws_t tmp_t : file cockpit_tmp_t [ ]"
        rlSESearchRule "allow cockpit_ws_t cockpit_tmp_t : dir { read write create getattr setattr lock unlink link rename add_name remove_name search rmdir open } [ ]"
        rlSESearchRule "allow cockpit_ws_t cockpit_tmp_t : file { read write create getattr setattr lock append unlink link rename open } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1374572"
        rlSEMatchPathCon "/usr/libexec/cockpit-session" "cockpit_session_exec_t"
        rlSEMatchPathCon "/usr/share/cracklib" "crack_db_t"
        rlSEMatchPathCon "/usr/share/cracklib/pw_dict.pwd" "crack_db_t"
        rlSEMatchPathCon "/etc/nshadow" "shadow_t"
        rlSESearchRule "allow cockpit_session_t crack_db_t : dir { search }"
        rlSESearchRule "allow cockpit_session_t crack_db_t : file { getattr open read }"
        rlSESearchRule "allow cockpit_session_t shadow_t : file { create write setattr }"
        rlSESearchRule "allow cockpit_session_t passwd_file_t : file { write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1413509"
        rlSEMatchPathCon "/usr/libexec/cockpit-ws" "cockpit_ws_exec_t"
        rlSEMatchPathCon "/usr/libexec/cockpit-ssh" "cockpit_session_exec_t"
        rlSEMatchPathCon "/var/lib/cockpit" "cockpit_var_lib_t"
        rlSEMatchPortCon tcp 22 ssh_port_t
        rlSESearchRule "allow cockpit_ws_t cockpit_session_exec_t : file { getattr open read execute }"
        rlSESearchRule "type_transition cockpit_ws_t cockpit_session_exec_t : process cockpit_session_t"
        rlSESearchRule "allow cockpit_ws_t cockpit_session_t : process { transition }"
        rlSESearchRule "allow cockpit_session_t cockpit_var_lib_t : dir { search }"
        rlSESearchRule "allow cockpit_session_t ssh_port_t : tcp_socket { name_connect } [ ]"
    rlPhaseEnd

    if ! rlIsRHEL 7 ; then
    rlPhaseStartTest "bz#1584167 + bz#1609929 + bz#1613638 + bz#1615318"
        rlSEMatchPathCon "/usr/sbin/sshd" "sshd_exec_t"
        rlSEMatchPathCon "/var/run/cockpit" "cockpit_var_run_t"
        rlSEMatchPathCon "/var/run/cockpit/active.motd" "cockpit_var_run_t"
        rlSESearchRule "allow sshd_t cockpit_var_run_t : dir { getattr open search } [ ]"
        rlSESearchRule "allow sshd_t cockpit_var_run_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1629678"
        rlSEMatchPathCon "/usr/lib/systemd/system/cockpit.socket" "cockpit_unit_file_t"
        rlSESearchRule "allow cockpit_ws_t cockpit_unit_file_t : service { status } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1561053"
        rlSEMatchPathCon "/usr/libexec/cockpit-ws" "cockpit_ws_exec_t"
        rlRun "ls -Z /proc/cpuinfo | grep :proc_t"
        rlSESearchRule "allow cockpit_ws_t proc_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "bz#1402316 + bz#1402495"
        rlSEMatchPathCon "/usr/libexec/cockpit-session" "cockpit_session_exec_t"
        rlSESearchRule "allow cockpit_session_t cockpit_session_t : process { setrlimit }"
    rlPhaseEnd

    if ! rlIsRHEL 7 ; then
    rlPhaseStartTest "bz#1718814"
        # staff_u section
        rlSESearchRule "allow staff_ssh_agent_t cockpit_session_t : fifo_file { getattr read write } [ ]"
        rlSESearchRule "allow staff_ssh_agent_t ssh_agent_tmp_t : dir { write } [ ]"
        rlSESearchRule "allow staff_t cockpit_ws_t : unix_stream_socket { getattr ioctl shutdown } [ ]"
        # rlSESearchRule "allow staff_sudo_t staff_t : unix_stream_socket { ioctl } [ ]"
        rlSESearchRule "allow cockpit_session_t staff_ssh_agent_t : process { signal } [ ]"
        # user_u section
        rlSESearchRule "allow user_ssh_agent_t cockpit_session_t : fifo_file { getattr read write } [ ]"
        rlSESearchRule "allow user_ssh_agent_t ssh_agent_tmp_t : dir { write } [ ]"
        rlSESearchRule "allow user_t cockpit_ws_t : unix_stream_socket { getattr ioctl shutdown } [ ]"
        # user_u cannot run sudo - tested in a different TC
        rlSESearchRule "allow cockpit_session_t user_ssh_agent_t : process { signal } [ ]"
        # sysadm_u section
        rlSESearchRule "allow sysadm_ssh_agent_t cockpit_session_t : fifo_file { getattr read write } [ ]"
        rlSESearchRule "allow sysadm_ssh_agent_t ssh_agent_tmp_t : dir { write } [ ]"

        # rlSESearchRule "allow sysadm_sudo_t sysadm_t : unix_stream_socket { ioctl } [ ]"
        rlSESearchRule "allow sysadm_t cockpit_ws_t : unix_stream_socket { getattr ioctl shutdown } [ ]"
        rlSESearchRule "allow cockpit_session_t sysadm_ssh_agent_t : process { signal } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1979182"
        rlSESearchRule "allow cockpit_ws_t fs_t : filesystem { getattr } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- xinetd service"
        HOST_ADDRESS="127.0.0.1" # IP address or nothing
        PORT_NUMBER="9090" # number or socket path
        PORT_TYPE="" # default is TCP, otherwise use -u (UDP) or --sctp (SCTP)
        if rlIsRHEL 5 6 ; then
            rlRun "chkconfig ${SERVICE_NAME} on"
            rlRun "service xinetd restart"
            rlLog "starting provocateur job"
            ( tail -f - | nc ${PORT_TYPE} ${HOST_ADDRESS} ${PORT_NUMBER} ) &
            PROVOCATEUR_PID=$!
        else
            rlRun "systemctl enable ${SERVICE_NAME}.socket"
            rlRun "systemctl start ${SERVICE_NAME}.socket"
            rlLog "starting provocateur job"
            ( tail -f - | ncat ${PORT_TYPE} ${HOST_ADDRESS} ${PORT_NUMBER} ) &
            PROVOCATEUR_PID=$!
        fi
        sleep 1
        rlRun "netstat -tupan | grep :${PORT_NUMBER}"
        rlRun "ps -o pid,user,context,args -C ${PROCESS_NAME}"
        rlRun "ps -o pid,user,context,args -C ${PROCESS_NAME} | grep :${PROCESS_CONTEXT}"
        rlRun "kill ${PROVOCATEUR_PID}"
        rlRun "killall ncat" 0,1
        if rlIsRHEL 5 6 ; then
            rlRun "chkconfig ${SERVICE_NAME} off"
            rlRun "service xinetd stop"
        else
            rlRun "systemctl stop ${SERVICE_NAME}.socket"
            rlRun "systemctl disable ${SERVICE_NAME}.socket"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

