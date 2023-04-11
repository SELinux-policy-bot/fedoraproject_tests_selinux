#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/mcstrans/Regression/bz442327-setfscreatecon-with-invalid-context
#   Description: setfscreatecon with invalid context can mistakenly succeed
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2009 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="mcstrans"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm selinux-policy
        rlAssertRpm libselinux
        OUTPUT_FILE=`mktemp`
        if rlIsRHEL 5 6 ; then
            rlServiceStop mcstrans
        else
            rlServiceStop mcstransd
        fi

        rlRun "setenforce 1"
        rlRun "sestatus"
        START_DATE_TIME=`date "+%m/%d/%Y %T"`
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#442327"
        if rlIsRHEL 5 6 ; then
            rlRun "service mcstrans start"
        else
            rlRun "service mcstransd start"
        fi
        sleep 1
        rlRun "for I in \`seq 1 1 5000\` ; do mkdir d --context=xyz 2>/dev/null && { t=X ; rmdir d ; } || t=. ; printf \$t ; done >& ${OUTPUT_FILE}"
        rlRun "grep -ci x ${OUTPUT_FILE}" 1
        sleep 1
        if rlIsRHEL 5 6 ; then
            rlRun "service mcstrans stop"
        else
            rlRun "service mcstransd stop"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlRun "ausearch -m AVC -m USER_AVC -ts ${START_DATE_TIME} > ${OUTPUT_FILE}" 0,1
        LINE_COUNT=`grep 'type=AVC' ${OUTPUT_FILE} | grep -v 'type=AVC.*denied.*mac_admin.*mkdir' | wc -l`
        rlAssert0 "number of unexpected AVCs in ${OUTPUT_FILE} should be 0" ${LINE_COUNT}

        if rlIsRHEL 5 6 ; then
            rlServiceRestore mcstrans
        else
            rlServiceRestore mcstransd
        fi

        rm -f ${OUTPUT_FILE}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

