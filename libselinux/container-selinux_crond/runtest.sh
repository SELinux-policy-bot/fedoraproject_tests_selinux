#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libselinux/Regression/container-selinux_crond
#   Description: Does installing container-selinux break crond?
#   Author:  Vit Mojzis <vmojzis@redhat.com>
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
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm cronie
        rlAssertRpm container-selinux
        rlRun "setenforce 1"
        rlRun "sestatus"
        OUTPUT_FILE=`mktemp`
        rlFileBackup /etc/crontab
    rlPhaseEnd

    rlPhaseStartTest "#1879368"
        rlRun "echo '* * * * * root date > /tmp/date' >> /etc/crontab"
        rlRun "restorecon -v /etc/crontab"
        rlRun "systemctl restart crond"
        # check if crond encountered any SELinux related issues
        rlRun "systemctl status crond | tee ${OUTPUT_FILE}"
        rlRun "cat ${OUTPUT_FILE} | grep -i 'SELinux'" 1
        rlRun "sleep 90"
        rlRun "cat /tmp/date &>${OUTPUT_FILE}"
        rlRun "sleep 90"
        # check that the job is still running
        rlRun "diff /tmp/date ${OUTPUT_FILE}" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f ${OUTPUT_FILE}"
        rlFileRestore
        rlRun "restorecon /etc/crontab"
        rlRun "systemctl restart crond"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
