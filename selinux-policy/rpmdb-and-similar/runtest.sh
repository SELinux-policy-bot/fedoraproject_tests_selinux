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
SERVICE_PACKAGE="rpm"
SERVICE_NAME="rpmdb-rebuild"
PROCESS_NAME="rpmdb"
PROCESS_CONTEXT="rpmdb_t"

rlJournalStart
    if rlIsRHEL '<9' || rlIsCentOS '<9' ; then
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

    rlPhaseStartTest "bz#1899548"
        rlSEMatchPathCon "/usr/bin/rpmdb" "rpmdb_exec_t"
        rlSESearchRule "allow rpmdb_t user_devpts_t : chr_file { read write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "touch /var/lib/rpm/.rebuilddb"
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlRun "touch /var/lib/rpm/.rebuilddb"
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "rpmdb executed by root/unconfined_t"
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
    rlPhaseEnd

    if [ -f /usr/lib/systemd/system/rpmdb-migrate.service ] ; then
    rlPhaseStartTest "bz#2164752"
        rlSEMatchPathCon "/usr/bin/rpm" "rpm_exec_t"
        rlSEMatchPathCon "/usr/lib/rpm/rpmdb_migrate" "rpmdb_exec_t"
        rlSEMatchPathCon "/var/lib/rpm" "rpm_var_lib_t"
        rlSEMatchPathCon "/var/lib/rpm/.migratedb" "rpm_var_lib_t"
        rlSESearchRule "allow rpmdb_t shell_exec_t : file { map execute } [ ]"
        rlSESearchRule "allow rpmdb_t rpm_exec_t : file { getattr open read map execute } [ ]"
        rlSESearchRule "allow rpmdb_t bin_t : file { getattr open read execute execute_no_trans } [ ]"
        rlSESearchRule "allow rpmdb_t rpm_var_lib_t : lnk_file { getattr read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- rpmdb-migrate service"
        rlRun "touch /var/lib/rpm/.migratedb"
        rlSEService - rpmdb-migrate - rpmdb_t "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlRun "touch /var/lib/rpm/.migratedb"
        rlSEService - rpmdb-migrate - rpmdb_t "restart status stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
        rlServiceRestore sssd
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

