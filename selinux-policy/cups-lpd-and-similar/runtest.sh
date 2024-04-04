#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/cups-lpd-and-similar
#   Description: SELinux interferes with cups-lpd and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/lib/cups/daemon/cups-lpd"
FILE_CONTEXT="cupsd_lpd_exec_t"
SERVICE_PACKAGE="cups-lpd"
SERVICE_NAME="cups-lpd"
PROCESS_NAME="cups-lpd"
PROCESS_CONTEXT="cupsd_lpd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        if rlIsRHEL 5 6 ; then
            rlServiceStop ${SERVICE_NAME}
        else
            rlSocketStop ${SERVICE_NAME}
        fi

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#192216"
        rlSEMatchPathCon "/usr/lib/cups/daemon/cups-lpd" "cupsd_lpd_exec_t"
        rlSEMatchPathCon "/var/run/cups" "cupsd_var_run_t"
        rlSESearchRule "allow cupsd_lpd_t cupsd_var_run_t : dir { search } [ ]"
        rlSESearchRule "allow cupsd_lpd_t cupsd_lpd_t : netlink_route_socket { create } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1004198"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="inetd_t" # xinetd runs the process
            BOOLEANS="[ cupsd_lpd_disable_trans ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="inetd_t" # xinetd runs the process
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPortCon "tcp" "515" "printer_port_t"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } ${BOOLEANS}"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} ${BOOLEANS}"
        if ! rlIsRHEL 5 6 ; then
            rlSESearchRule "allow ${PROCESS_CONTEXT} printer_port_t : tcp_socket { name_bind }"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#1420522 + bz#1554118"
        rlSEMatchPathCon "/usr/lib/cups/daemon/cups-lpd" "cupsd_lpd_exec_t"
        rlSESearchRule "allow init_t cupsd_lpd_t : tcp_socket { create setopt bind listen }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1919399 + bz#1947397"
        rlSEMatchPathCon "/usr/lib/cups/daemon/cups-lpd" "cupsd_lpd_exec_t"
        rlSEMatchPathCon "/run/cups/cups.sock" "cupsd_var_run_t"
        rlSESearchRule "allow cupsd_lpd_t cupsd_var_run_t : sock_file { read } [ ]"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 7 8 && ! rlIsCentOS 5 6 7 8 ; then
    rlPhaseStartTest "bz#2020531"
        rlSEMatchPathCon "/usr/lib/cups/daemon/cups-lpd" "cupsd_lpd_exec_t"
        rlRun "ls -Z /proc/1/environ | grep :init_t"
        rlSESearchRule "dontaudit cupsd_lpd_t init_t : dir { search } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- bz#1919399 + bz#1947397"
        rlRun "systemctl start cups.service"
        rlRun "systemctl enable cups-lpd.socket"
        rlRun "systemctl start cups-lpd.socket"
        sleep 2
        rlRun "lpadmin -p test -o printer-is-shared=true -E"
        rlRun "DEVICE_URI=lpd://127.0.0.1/test /usr/lib/cups/backend/lpd 1 user test 1 '' /etc/fstab"
        sleep 5
        rlRun "lpadmin -x test"
        rlRun "systemctl stop cups-lpd.socket"
        rlRun "systemctl disable cups-lpd.socket"
        rlRun "systemctl stop cups.service"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- xinetd service"
        HOST_ADDRESS="127.0.0.1" # IP address or nothing
        PORT_NUMBER="515" # number or socket path
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
        if rlIsRHEL 5 6 ; then
            rlServiceRestore ${SERVICE_NAME}
        else
            rlSocketRestore ${SERVICE_NAME}
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

