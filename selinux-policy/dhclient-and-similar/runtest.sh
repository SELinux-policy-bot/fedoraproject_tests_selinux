#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/dhclient-and-similar
#   Description: SELinux interferes with dhclient and related programs
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
SERVICE_PACKAGE="chrony"
SERVICE_NAME="chronyd"

rlJournalStart
    rlLog "If this test fails, please contact mmalik on IRC #selinux"
    rlLog "This test should fail if tested bugs are NOT fixed yet"
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStart ${SERVICE_NAME}
        rlFileBackup --missing-ok /run/chrony-dhcp

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 8 ; then
    rlPhaseStartTest "bz#1897388"
        rlSEMatchPathCon "/usr/sbin/dhclient-script" "dhcpc_exec_t"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSESearchRule "allow dhcpc_t chronyc_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition dhcpc_t chronyc_exec_t : process chronyc_t"
        rlSESearchRule "allow dhcpc_t chronyc_t : process { transition } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2035117 + bz#2093709 + bz#2094155"
        rlSEMatchPathCon "/usr/sbin/dhclient-script" "dhcpc_exec_t"
        rlSEMatchPathCon "/run/chrony-dhcp" "chronyd_var_run_t"
        rlSEMatchPathCon "/run/chrony-dhcp/eth0.sources" "chronyd_var_run_t"
        rlSESearchRule "type_transition dhcpc_t var_run_t : dir chronyd_var_run_t chrony-dhcp"
        rlSESearchRule "allow dhcpc_t chronyd_var_run_t : dir { read write } [ ]"
        rlSESearchRule "allow dhcpc_t chronyd_var_run_t : file { create getattr append } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "rm -rf /run/chrony-dhcp"
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlRun "dhclient"
        DHCLIENT_PID=`pgrep dhclient`
        rlRun "ps -efZ | grep dhclient"
        rlRun "ps -efZ | grep ':dhcpc_t:.*dhclient'"
        if ! rlIsRHEL 8 ; then
            rlRun "ls -alZ /run/chrony-dhcp"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        kill ${DHCLIENT_PID}
        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

