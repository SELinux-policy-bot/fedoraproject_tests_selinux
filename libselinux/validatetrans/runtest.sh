#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libselinux/Sanity/validatetrans
#   Description: Does the validatetrans tool work as expected?
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

PACKAGE="libselinux"

rlJournalStart
    # validatetrans utility is available since Fedora 32
    if ! rlIsRHEL ">8" && ! rlIsFedora ">31" && ! rlIsCentOS ">8" ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlRun "rpm -qf `which validatetrans`"
        rlRun "rpm -qf `which seinfo`"
        rlRun "rpm -qf `which semodule`"
        rlRun "rpm -qf `which ausearch`"

        rlSESetEnforce
        rlSEStatus
    rlPhaseEnd

    rlPhaseStartTest "correct usage"
        rlRun "seinfo --validatetrans"
        rlRun "semodule -i testpolicy.cil"
        rlRun "seinfo --validatetrans"
        rlRun "mkdir -p tested-dir"
        rlRun "touch tested-file"
        rlRun "mkfifo tested-fifo_file"
        for TCLASS in dir file fifo_file ; do
            rlSESetTimestamp
            sleep 1
            rlRun "chcon -t bin_t tested-${TCLASS}"
            # file context change from anything to swapfile_t should pass
            rlRun "validatetrans unconfined_u:object_r:bin_t:s0 unconfined_u:unconfined_r:unconfined_t:s0 ${TCLASS} unconfined_u:object_r:swapfile_t:s0" 0
            rlRun "chcon -t swapfile_t tested-${TCLASS}"
            # file context change from swapfile_t to anything should fail
            rlRun "validatetrans unconfined_u:object_r:swapfile_t:s0 unconfined_u:unconfined_r:unconfined_t:s0 ${TCLASS} unconfined_u:object_r:bin_t:s0" 255
            rlRun "chcon -t bin_t tested-${TCLASS}" 1
            sleep 1
            rlSECheckAVC --expect "type=SELINUX_ERR.*op=security_validate_transition.*:swapfile_t:.*:bin_t:.*tclass=${TCLASS}"
            rlRun "rm -rf tested-${TCLASS}"
        done
        rlRun "semodule -r testpolicy"
        rlRun "seinfo --validatetrans"
    rlPhaseEnd

    rlPhaseStartTest "incorrect number of parameters"
        rlRun "validatetrans param1 2>&1 | grep -i usage"
        rlRun "validatetrans param1 param2 2>&1 | grep -i usage"
        rlRun "validatetrans param1 param2 param3 2>&1 | grep -i usage"
        rlRun "validatetrans param1 param2 param3 param4 param5 2>&1 | grep -i usage"
    rlPhaseEnd

    rlPhaseStartTest "incomplete or invalid parameters"
        # first context incomplete
        rlRun "validatetrans unconfined_u:object_r:bin_t: unconfined_u:unconfined_r:unconfined_t:s0 file unconfined_u:object_r:swapfile_t:s0 2>&1 | grep -i -e 'invalid argument' -e 'invalid source context'"
        # second context incomplete
        rlRun "validatetrans unconfined_u:object_r:bin_t:s0 unconfined_u:unconfined_r:unconfined_t: file unconfined_u:object_r:swapfile_t:s0 2>&1 | grep -i -e 'invalid argument' -e 'invalid target context'"
        # third context incomplete
        rlRun "validatetrans unconfined_u:object_r:bin_t:s0 unconfined_u:unconfined_r:unconfined_t:s0 file unconfined_u:object_r:swapfile_t: 2>&1 | grep -i -e 'invalid argument' -e 'invalid new context'"
        # invalid target class
        rlRun "validatetrans unconfined_u:object_r:bin_t:s0 unconfined_u:unconfined_r:unconfined_t:s0 xyz unconfined_u:object_r:swapfile_t:s0 2>&1 | grep -i 'invalid class'"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

