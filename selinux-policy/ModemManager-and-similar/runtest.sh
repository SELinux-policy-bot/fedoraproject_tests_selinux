#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/ModemManager-and-similar
#   Description: SELinux interferes with ModemManager and related programs
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
if rlIsRHEL 6 ; then
    FILE_PATH="/usr/sbin/modem-manager"
    PROCESS_NAME="modem-manager"
else
    FILE_PATH="/usr/sbin/ModemManager"
    PROCESS_NAME="ModemManager"
fi
FILE_CONTEXT="modemmanager_exec_t"
SERVICE_PACKAGE="ModemManager"
SERVICE_NAME="ModemManager"
PROCESS_CONTEXT="modemmanager_t"

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

    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="system_dbusd_t" # D-bus daemon runs the process
        else # RHEL-7 etc.
            for SOURCE_TYPE in system_dbusd_t init_t ; do
                rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute }"
                rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition }"
                rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
            done
        fi
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "real scenario -- DBus service"
        if rlIsRHEL 6 ; then
            DESTINATION="org.freedesktop.ModemManager"
        else
            DESTINATION="org.freedesktop.ModemManager1"
        fi
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1120152"
        rlSEMatchPathCon "/usr/sbin/ModemManager" "modemmanager_exec_t"
        rlSESearchRule "allow modemmanager_t modemmanager_t : unix_stream_socket { connectto }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1362273 + bz#1365214"
        rlSEMatchPathCon "/usr/sbin/ModemManager" "modemmanager_exec_t"
        rlSEMatchPathCon "/run/systemd/inhibit/7.ref" "systemd_logind_inhibit_var_run_t"
        rlSESearchRule "allow modemmanager_t systemd_logind_t : dbus { send_msg }"
        rlSESearchRule "allow systemd_logind_t modemmanager_t : dbus { send_msg }"
        rlSESearchRule "allow modemmanager_t systemd_logind_inhibit_var_run_t : fifo_file { write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1676810 + bz#1697868"
        rlSEMatchPathCon "/usr/sbin/ModemManager" "modemmanager_exec_t"
        rlSESearchRule "allow modemmanager_t sysfs_t : file { append write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        sleep 1
        rlRun "service systemd-logind restart"
        sleep 1
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    if ! rlIsRHEL 6 7 8 ; then
    rlPhaseStartTest "bz#1996903 + bz#1996905 + bz#2001141 + bz#2001143 + bz#2001144 + bz#2001145 + bz#2036582"
        rlSEMatchPathCon "/usr/sbin/ModemManager" "modemmanager_exec_t"
        rlSESearchRule "allow modemmanager_t modemmanager_t : qipcrtr_socket { create getattr getopt } [ ]"
        rlSESearchRule "allow modemmanager_t kernel_t : system { module_request } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1961571 + bz#2000196"
        rlSEMatchPathCon "/usr/sbin/ModemManager" "modemmanager_exec_t"
        rlSEMatchPathCon "/dev/wwan0p1QCDM" "modem_device_t"
        rlSEMatchPathCon "/dev/wwan0p2MBIM" "modem_device_t"
        rlRun "semanage fcontext -l | grep '^/dev/wwan.*char.*modem_device_t'"
        rlSESearchRule "allow modemmanager_t modem_device_t : chr_file { getattr open read write ioctl } [ ]"
        rlSESearchRule "allow modemmanager_t unconfined_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2145005 + bz#2149560 + bz#2149954"
        rlSESearchRule "allow modemmanager_t modemmanager_t : netlink_route_socket { create getopt getattr nlmsg_write } [ ]"
        rlSESearchRule "allow modemmanager_t sysfs_t : dir { write add_name } [ ]"
        rlSESearchRule "allow modemmanager_t sysfs_t : file { create } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlFileRestore

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

