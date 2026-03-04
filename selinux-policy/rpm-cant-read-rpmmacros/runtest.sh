#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of selinux-policy/rpm-cant-read-rpmmacros
#   Description: setroubleshootd process should not cause an AVC when trying to read /root/.rpmmacros
#   Author: Veronika Syncakova <vsyncako@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
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

PACKAGE="setroubleshoot-server"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        rlRun "rlFileBackup --clean /root/.rpmmacros"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-142548 + RHEL-147470"
        # check that sedispatch is running and therefore setroubleshoot-server is installed
        rlRun "ps -efZ | grep sedispatch"
        rlSESearchRule "dontaudit setroubleshootd_t admin_home_t : file { read } [ ]"
        rlRun "touch /root/.rpmmacros"
        # trigger selinux denial
        rlRun "passwd --help >& /root/output.txt"
        sleep 5
    rlPhaseEnd

    rlPhaseStartCleanup
        rlSECheckAVC --ignore 'type=AVC .* denied  { write } .*:passwd_t.* ' \
                     --ignore '.*passwd.*'
        rlRun "rlFileRestore"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd