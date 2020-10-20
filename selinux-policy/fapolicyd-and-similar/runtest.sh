#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/fapolicyd-and-similar
#   Description: SELinux interferes with fapolicyd and related programs
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
FILE_PATH="/usr/sbin/fapolicyd"
FILE_CONTEXT="fapolicyd_exec_t"
SERVICE_PACKAGE="fapolicyd"
SERVICE_NAME="fapolicyd"
PROCESS_NAME="fapolicyd"
PROCESS_CONTEXT="fapolicyd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}
        rlAssertRpm ${SERVICE_PACKAGE}-selinux

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1865818"
        rlSEMatchPathCon "/usr/sbin/fapolicyd" ${FILE_CONTEXT}
        rlSEMatchPathCon "/etc/resolv.conf" "net_conf_t"
        rlSESearchRule "allow ${PROCESS_CONTEXT} net_conf_t : lnk_file { getattr read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1874491"
        rlSEMatchPathCon "/usr/sbin/fapolicyd" ${FILE_CONTEXT}
        rlSEMatchPathCon "/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSESearchRule "allow fapolicyd_t system_dbusd_var_run_t : sock_file { write } [ ]"
        rlSESearchRule "allow fapolicyd_t system_dbusd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow fapolicyd_t system_dbusd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow system_dbusd_t fapolicyd_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1876538"
        rlSEMatchPathCon "/usr/sbin/fapolicyd" ${FILE_CONTEXT}
        rlSEMatchPathCon "/var/lib/rpm" "rpm_var_lib_t"
        rlSEMatchPathCon "/var/lib/rpm/.dbenv.lock" "rpm_var_lib_t"
        rlSESearchRule "allow fapolicyd_t rpm_var_lib_t : dir { write add_name } [ ]"
        rlSESearchRule "allow fapolicyd_t rpm_var_lib_t : file { create } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for OSes where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var"
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

