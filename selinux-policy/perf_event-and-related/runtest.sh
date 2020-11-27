#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/perf_event-and-related
#   Description: the service was running as initrc_t or init_t, now it is confined by SELinux
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

rlJournalStart
    rlLog "If this test fails, please contact mmalik on IRC #selinux"
    rlLog "This test should fail if tested bugs are NOT fixed yet"
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm perf

        rlRun "semodule -c -E base"
        if grep -q perf_event base.cil ; then
            rlLog "current SELinux policy already defines the perf_event class"
            UPDATED_BASE_CIL=false
        else
            rlLog "current SELinux policy does NOT define the perf_event class"
            rlLog "going to define the perf_event class for testing purposes"
            rlRun "sed -i 's/^\(.*classorder.*\)))$/(class perf_event (open cpu kernel tracepoint read write ))\n\1 perf_event ))/' base.cil"
            rlRun "semodule -i base.cil"
            UPDATED_BASE_CIL=true
        fi

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1901957"
        rlSESearchRule "allow unconfined_t unconfined_t : perf_event { open cpu kernel read write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- perf tool under root"
        rlRun "perf record -o /dev/null echo test"
        rlRun "seinfo -c perf_event -x"
        rlRun "sesearch -c perf_event -A --dontaudit"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- confined root sysadm_u"
        rlRun "setsebool ssh_sysadm_login on"
        USER_NAME="toor"
        USER_SECRET="S3kr3t${RANDOM}"
        rlRun "useradd -o -u 0 -g 0 -Z sysadm_u ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "./ssh.exp ${USER_NAME}/sysadm_r ${USER_SECRET} localhost perf record -o /dev/null echo test"
        rlRun "userdel -Z ${USER_NAME}"
        rlRun "setsebool ssh_sysadm_login off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        if ${UPDATED_BASE_CIL} ; then
            rlRun "semodule -r base"
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

