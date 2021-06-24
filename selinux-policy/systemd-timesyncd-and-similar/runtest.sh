#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-timesyncd-and-similar
#   Description: SELinux interferes with systemd-timesyncd and related programs
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
FILE_PATH="/usr/lib/systemd/systemd-timesyncd"
FILE_CONTEXT="systemd_timedated_exec_t"
SERVICE_PACKAGE="systemd-udev"
SERVICE_NAME="systemd-timesyncd"
PROCESS_NAME="systemd-timesyncd"
PROCESS_CONTEXT="systemd_timedated_t"

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

    rlPhaseStartTest "bz#1640801"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-timesyncd" "systemd_timedated_exec_t"
        rlSEMatchPathCon "/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSESearchRule "allow systemd_timedated_t system_dbusd_var_run_t : sock_file { read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1649668 + bz#1653050"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-timesyncd" "systemd_timedated_exec_t"
        rlSEMatchPathCon "/run/systemd/netif/links" "systemd_networkd_var_run_t"
        rlSEMatchPathCon "/run/systemd/netif/state" "systemd_networkd_var_run_t"
        rlSESearchRule "allow systemd_timedated_t systemd_networkd_var_run_t : dir { read } [ ]"
        rlSESearchRule "allow systemd_timedated_t systemd_networkd_var_run_t : file { getattr open read } [ ]"
    rlPhaseEnd

    if rlIsFedora ; then
    rlPhaseStartTest "bz#1649671"
        rlSEMatchPathCon "/run/systemd/timesync" "init_var_run_t"
        rlSEMatchPathCon "/run/systemd/timesync/synchronized" "init_var_run_t"
        rlSESearchRule "allow systemd_timedated_t init_var_run_t : dir { write add_name } [ ]"
        rlSESearchRule "allow systemd_timedated_t init_var_run_t : file { create write open } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1694272"
        rlRun "ls -Z /proc/net/unix | grep :proc_net_t"
        rlSESearchRule "allow systemd_timedated_t proc_net_t : dir { getattr open search } [ ]"
        rlSESearchRule "allow systemd_timedated_t proc_net_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1822131"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-timesyncd" "systemd_timedated_exec_t"
        rlSEMatchPathCon "/run/systemd/timesync" "systemd_timedated_var_run_t"
        rlSEMatchPathCon "/run/systemd/timesync/synchronized" "systemd_timedated_var_run_t"
        rlSESearchRule "allow systemd_timedated_t systemd_timedated_var_run_t : file { getattr write } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1649257 + bz#1666222"
        rlSESearchRule "allow init_t systemd_timedated_t : process { transition } [ ]"
        rlSESearchRule "type_transition init_t systemd_timedated_exec_t : process systemd_timedated_t"
        rlSESearchRule "allow init_t systemd_timedated_t : process2 { nnp_transition } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1869979"
        rlSESearchRule "allow systemd_timedated_t efivarfs_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1949315"
        rlSEMatchPathCon "/" "root_t"
        rlSEMatchPathCon "/run" "var_run_t"
        rlSESearchRule "allow systemd_timedated_t root_t : dir { watch } [ ]"
        rlSESearchRule "allow systemd_timedated_t var_run_t : dir { watch } [ ]"
    rlPhaseEnd

    if systemctl list-units | grep -q ${SERVICE_NAME} ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
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

