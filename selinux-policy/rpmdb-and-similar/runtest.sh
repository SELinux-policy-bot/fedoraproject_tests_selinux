#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/rpmdb-and-similar
#   Description: SELinux interferes with rpmdb program, rpmdb-rebuild service and related programs.
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
ROOT_PASSWORD="redhat"
SERVICE_PACKAGE="rpm"
SERVICE_NAME="rpmdb-rebuild"
PROCESS_NAME="rpmdb"
PROCESS_CONTEXT="rpmdb_t"

rlJournalStart
    if rlIsRHEL '<9' ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlLog "If this test fails, please contact mmalik or IRC #selinux"
    rlLog "This test should fail if tested bugs are NOT fixed yet"
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlServiceStart sssd
        rlFileBackup /var/lib/rpm

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1898298"
        rlSEMatchPathCon "/usr/bin/rpmdb" "rpmdb_exec_t"
        rlSEMatchPathCon "/etc/resolv.conf" "net_conf_t"
        rlSESearchRule "allow rpmdb_t net_conf_t : lnk_file { getattr read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1899548"
        # also covers duplicates: 1900383, 1900386, 1900388, 1900389, 1900390, 1900391
        rlSEMatchPathCon "/usr/bin/rpmdb" "rpmdb_exec_t"
        rlSEMatchPathCon "/var/lib/sss/mc/passwd" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSEMatchPathCon "/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSESearchRule "allow rpmdb_t user_devpts_t : chr_file { read write } [ ]"
        rlSESearchRule "dontaudit rpmdb_t sssd_public_t : file { getattr open map } [ ]"
        rlSESearchRule "dontaudit rpmdb_t sssd_var_lib_t : sock_file { write } [ ]"
        rlSESearchRule "dontaudit rpmdb_t sssd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "dontaudit rpmdb_t system_dbusd_var_run_t : sock_file { write } [ ]"
        rlSESearchRule "dontaudit rpmdb_t system_dbusd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "dontaudit rpmdb_t system_dbusd_t : dbus { send_msg } [ ]"
        rlSESearchRule "dontaudit system_dbusd_t rpmdb_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "touch /var/lib/rpm/.rebuilddb"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var"
        rlRun "touch /var/lib/rpm/.rebuilddb"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "rpmdb executed by root/unconfined_t"
        rlRun "semodule -DB"
        rlRun "restorecon -Rv /var/lib/rpm"
        rlRun "ls -Z `which rpmdb`"
        rlRun "rpmdb --help"
        OUTPUT_FILE=`mktemp`
        rlRun "rpmdb --exportdb >& ${OUTPUT_FILE}"
        rlRun "ls -l ${OUTPUT_FILE}"
        rlRun "ls -dZ /var/lib/rpm | grep :rpm_var_lib_t"
        rlRun "ls -Z /var/lib/rpm"
        rlRun "cat ${OUTPUT_FILE} | rpmdb --importdb"
        rlRun "ls -dZ /var/lib/rpm | grep :rpm_var_lib_t"
        rlRun "ls -Z /var/lib/rpm"
        rm -f ${OUTPUT_FILE}
        rlRun "semodule -B"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
        rlServiceRestore sssd
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

