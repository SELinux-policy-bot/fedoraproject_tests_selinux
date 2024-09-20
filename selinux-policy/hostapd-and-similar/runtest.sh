#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/hostapd-and-similar
#   Description: SELinux interferes with hostapd and related programs
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
FILE_PATH="/usr/sbin/hostapd"
FILE_CONTEXT="hostapd_exec_t"
SERVICE_PACKAGE="hostapd"
SERVICE_NAME="hostapd"
PROCESS_NAME="hostapd"
PROCESS_CONTEXT="hostapd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}
        rlRun "rpm -qa kernel\*"
        rlRun "uname -a"
        rlRun "yum -y install kernel-modules-internal-`uname -r` --enablerepo '*'"
        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow
        rlFileBackup /etc/hostapd/hostapd.conf

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined ${PROCESS_CONTEXT} ; then
    rlPhaseStartTest "bz#1224405"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/run/hostapd" "hostapd_var_run_t"
        rlSEMatchPathCon "/run/hostapd/wlan0" "hostapd_var_run_t"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlSESearchRule "dontaudit hostapd_t debugfs_t : dir { search } [ ]"
        rlSESearchRule "allow hostapd_t hostapd_var_run_t : sock_file { create setattr unlink } [ ]"
        rlSESearchRule "allow hostapd_t hostapd_t : capability { fsetid } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1225245"
        rlSESearchRule "allow hostapd_t hostapd_t : capability { net_admin } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1237343"
        rlSESearchRule "allow hostapd_t hostapd_t : capability { net_raw } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1266068 + bz#1273570 + bz#1278569 + bz#1282179 + bz#1334021 + bz#1343683"
        rlSESearchRule "allow hostapd_t hostapd_t : netlink_generic_socket { create setopt bind getattr } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1977676 + bz#1979968"
        rlSEMatchPathCon "/usr/sbin/hostapd" "hostapd_exec_t"
        rlSEMatchPortCon udp 67 dhcpd_port_t
        rlSESearchRule "allow hostapd_t hostapd_t : capability { net_bind_service } [ ]"
        rlSESearchRule "allow hostapd_t dhcpd_port_t : udp_socket { name_bind } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1784253 + bz#2032277"
        rlSESearchRule "allow hostapd_t user_tmp_t : sock_file { write } [ ]"
        rlSESearchRule "allow hostapd_t unconfined_t : unix_dgram_socket { sendto } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlRun "modprobe mac80211_hwsim"
        rlRun "sed -i 's/^interface=.*$//' /etc/hostapd/hostapd.conf"
        rlRun "sed -i 's/^hw_mode=.*$//' /etc/hostapd/hostapd.conf"
        rlRun "sed -i 's/^channel=.*$//' /etc/hostapd/hostapd.conf"
        rlRun "sed -i 's/^ssid=.*//' /etc/hostapd/hostapd.conf"
        rlRun "echo interface=wlan0 >> /etc/hostapd/hostapd.conf"
        rlRun "echo hw_mode=g >> /etc/hostapd/hostapd.conf"
        rlRun "echo channel=10 >> /etc/hostapd/hostapd.conf"
        rlRun "echo ssid=somename >> /etc/hostapd/hostapd.conf"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlRun "hostapd_cli all_sta"
        rlRun "systemd-run hostapd_cli ping"
        sleep 5
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

