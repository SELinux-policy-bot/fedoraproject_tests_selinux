#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/setools/Sanity/sesearch
#   Description: Does sesearch work well? Does it support all features?
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

PACKAGE="setools"

rlJournalStart
    rlPhaseStartSetup
        if rlIsRHEL 5 ; then
            rlAssertRpm ${PACKAGE}
        elif rlIsRHEL 6 7 ; then
            rlAssertRpm ${PACKAGE}-libs
            rlAssertRpm ${PACKAGE}-console
        else
            rlAssertRpm ${PACKAGE}-console
        fi
    rlPhaseEnd

    if rlIsRHEL '<=7' ; then
    rlPhaseStartTest "Records counting"
        if rlIsRHEL 5 6 ; then
            rlRun "MAX_COUNT=\`sesearch --all | wc -l\`"
        else
            rlRun "MAX_COUNT=\`sesearch --allow --auditallow --dontaudit --type --role_allow --role_trans --range_trans | wc -l\`"
        fi
        if rlIsRHEL 5 ; then
            for PARAM in "allow" "neverallow" "audit" "role_trans" "type" ; do
                rlRun "FULL_COUNT=\`sesearch --${PARAM} | wc -l\`"
                rlRun "echo \${FULL_COUNT}"
                rlRun "FILTERED_COUNT=\`sesearch --${PARAM} | grep ${PARAM} | wc -l\`"
                rlRun "echo \${FILTERED_COUNT}"
                rlAssertGreaterOrEqual "the difference must be between 0 and 2" 2 $((FULL_COUNT - FILTERED_COUNT))
                rlAssertGreaterOrEqual "the difference must be between 0 and 2" $((FULL_COUNT - FILTERED_COUNT)) 0
                rlAssertGreaterOrEqual "number of all rules must be greater or equal to this number" ${MAX_COUNT} ${FULL_COUNT}
            done

            rlRun "FULL_COUNT=\`sesearch --rangetrans | wc -l\`"
            rlRun "echo \${FULL_COUNT}"
            rlRun "FILTERED_COUNT=\`sesearch --rangetrans | grep range_trans | wc -l\`"
            rlRun "echo \${FILTERED_COUNT}"
            rlAssertGreaterOrEqual "the difference must be between 0 and 2" 2 $((FULL_COUNT - FILTERED_COUNT))
            rlAssertGreaterOrEqual "the difference must be between 0 and 2" $((FULL_COUNT - FILTERED_COUNT)) 0
            rlAssertGreaterOrEqual "number of all rules must be greater or equal to this number" ${MAX_COUNT} ${FULL_COUNT}
        else
            for PARAM in "allow" "neverallow" "auditallow" "dontaudit" "range_trans" "role_trans" "type" ; do
                rlRun "FULL_COUNT=\`sesearch --${PARAM} | grep -v -e 'Found ' -e '^$' | wc -l\`"
                rlRun "echo \${FULL_COUNT}"
                rlRun "FILTERED_COUNT=\`sesearch --${PARAM} | grep -v -e 'Found ' -e '^$' | grep ${PARAM} | wc -l\`"
                rlRun "echo \${FILTERED_COUNT}"
                rlAssertEquals "these 2 numbers should be equal" ${FULL_COUNT} ${FILTERED_COUNT}
                rlAssertGreater "number of all rules must be greater than any of these numbers" ${MAX_COUNT} ${FULL_COUNT}
            done
        fi

        rlRun "FULL_COUNT=\`sesearch --role_allow | wc -l\`"
        rlRun "echo \${FULL_COUNT}"
        rlRun "FILTERED_COUNT=\`sesearch --role_allow | grep allow | wc -l\`"
        rlRun "echo \${FILTERED_COUNT}"
        rlAssertGreaterOrEqual "the difference must be between 0 and 2" 2 $((FULL_COUNT - FILTERED_COUNT))
        rlAssertGreaterOrEqual "the difference must be between 0 and 2" $((FULL_COUNT - FILTERED_COUNT)) 0
        rlAssertGreaterOrEqual "number of all rules must be greater or equal to this number" ${MAX_COUNT} ${FULL_COUNT}
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#649711 + bz#650094 + bz#924588"
        rlLog "All three bugs were closed as WONTFIX, so this phase was commented out"
        #for SHORT_OPTION in "-s" "-t" "-c" ; do
            #rlRun "sesearch -A ${SHORT_OPTION} xxx" 1-255
        #done

        #for LONG_OPTION in "--source" "--target" "--class" ; do
            #rlRun "sesearch --allow ${LONG_OPTION}=xxx" 1-255
        #done
    rlPhaseEnd

    if rlIsRHEL '<=7' ; then
    rlPhaseStartTest "bz#836213"
        rlRun "sesearch -s ipsec_t -t ipsec_mgmt_t -c process --allow 2>&1 | grep -i \"found .* av rules\""
        rlRun "sesearch -s ipsec_t -t ipsec_mgmt_t -c process --dontaudit 2>&1 | grep -i \"found .* av rules\""
        rlRun "sesearch -s ipsec_t -t ipsec_mgmt_t -c process --all 2>&1 | grep -i \"found .* av rules\""
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1029837"
        if rlIsRHEL 5 6 ; then
            SELINUX_FS="/selinux"
        else
            SELINUX_FS="/sys/fs/selinux"
        fi
        rlRun "sesearch -T ${SELINUX_FS}/policy >/dev/null"
        for POLICY_TYPE in minimum mls targeted ; do
            if [ -f /etc/selinux/${POLICY_TYPE}/policy/policy.* ] ; then
                rlRun "sesearch -T /etc/selinux/${POLICY_TYPE}/policy/policy.* >/dev/null"
            fi
        done
    rlPhaseEnd

    rlPhaseStartTest "bz#1595582"
        REFERENCE_FILE=`mktemp`
        OUTPUT_FILE=`mktemp`
        REAL_TYPE="spamc_home_t"
        rlRun "sesearch -t ${REAL_TYPE} --allow --dontaudit --auditallow | sort > ${REFERENCE_FILE}"
        for ALIAS in spamassassin_home_t pyzor_home_t razor_home_t ; do
            rlRun "sesearch -t ${ALIAS} --allow --dontaudit --auditallow | sort > ${OUTPUT_FILE}"
            rlRun "diff ${REFERENCE_FILE} ${OUTPUT_FILE}"
        done
        rm -f ${REFERENCE_FILE} ${OUTPUT_FILE}
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

