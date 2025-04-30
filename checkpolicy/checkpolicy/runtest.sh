#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/checkpolicy/Sanity/checkpolicy
#   Description: runs checkpolicy with various options to find out if it behaves correctly
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

PACKAGE="checkpolicy"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        if rlIsRHEL "<9" ; then
            rlAssertRpm selinux-policy-minimum
        fi
        rlAssertRpm selinux-policy-mls
        rlAssertRpm selinux-policy-targeted
        rlRun "rpm -qa | grep kernel"
        rlRun "uname -a"
        TEST_FILE=`mktemp`
        TEST_DIR=`mktemp -d`
        OUTPUT_FILE=`mktemp`
        rlAssertExists "/usr/bin/checkpolicy"
        rlAssertExists "/usr/share/man/man8/checkpolicy.8.gz"
    rlPhaseEnd

    rlPhaseStartTest "compilation from policy.conf"
        MIN_VERSION="15"
        MAX_VERSION=`find /etc/selinux/ -name policy.?? | cut -d / -f 6 | cut -d . -f 2 | head -n 1`
        if rlIsRHEL 5 6 ; then
            VERSIONS=`seq ${MIN_VERSION} 1 ${MAX_VERSION}`
        else
            # some versions are skipped because of BZ#1328979
            VERSIONS=`seq ${MIN_VERSION} 1 ${MAX_VERSION} | grep -v -e 19 -e 20 -e 21 -e 22 -e 23`
        fi
        for CUR_VERSION in ${VERSIONS} ; do
            rlRun "rm -f policy.out"
            rlWatchdog "checkpolicy -M -c ${CUR_VERSION} -o policy.out policy.conf.from.secilc" 15
            if [ -s policy.out ] ; then
                rlRun "seinfo policy.out 2>&1 | tee ${OUTPUT_FILE}"
                rlRun "grep -i -e \"policy version.*${CUR_VERSION}\" -e \"unable to open policy\" ${OUTPUT_FILE}"
            else
                rlRun "ls -l policy.out"
            fi
        done
    rlPhaseEnd

    rlPhaseStartTest "bz#533790"
        rlRun "checkpolicy >& ${TEST_FILE}" 1
        rlAssertGrep "unable to open policy.conf" ${TEST_FILE}
        rlRun "checkpolicy -b >& ${TEST_FILE}" 1
        rlAssertGrep "Can't open 'policy':  No such file or directory" ${TEST_FILE}
        rlRun "checkpolicy -V"
        rlRun "checkpolicy -U 2>&1 | grep \"option requires an argument\""
        rlRun "checkpolicy -U xyz" 1
        rlRun "rm -f policy.conf"
        if ! rlIsRHEL 4 ; then
            for OPTION in "deny" "reject" "allow" ; do
                rlRun "checkpolicy -U ${OPTION} >& ${TEST_FILE}" 1
                rlAssertGrep "unable to open policy.conf" ${TEST_FILE}
            done
        fi
        rlRun "rm -f ${TEST_FILE}"
        rlRun "touch ${TEST_FILE}"
        rlRun "rm -rf ${TEST_DIR}"
        rlRun "mkdir ${TEST_DIR}"
        rlRun "checkpolicy ${TEST_FILE}" 1,2
        rlRun "checkpolicy -b ${TEST_FILE}" 1
        rlRun "checkpolicy ${TEST_DIR}" 1,2
        rlRun "checkpolicy -b ${TEST_DIR}" 1
        rlRun "rm -f ${TEST_FILE}"
        rlRun "rm -rf ${TEST_DIR}"
        rlRun "checkpolicy ${TEST_FILE}" 1
        rlRun "checkpolicy -b ${TEST_FILE}" 1
        rlRun "checkpolicy -c 2>&1 | grep \"option requires an argument\""
        rlRun "checkpolicy -c 0 2>&1 | grep \"value 0 not in range\""
        rlRun "checkpolicy -t 2>&1 | grep \"option requires an argument\""
        rlRun "checkpolicy -t xyz 2>&1 | grep -i \"unknown target platform\""
        if [ -e "/usr/share/man/man8/checkmodule.8.gz" ]; then
            rlRun "man checkpolicy | col -b | grep -- '-m]'" 1
        fi
        rlRun "checkpolicy --help 2>&1 | grep -- '-m]'" 1
    rlPhaseEnd

    rlPhaseStartTest "bz#739866"
        if rlIsRHEL 5 6 ; then
            ACTIVE_POLICY="/selinux/policy"
        else
            ACTIVE_POLICY="/sys/fs/selinux/policy"
        fi
        rlRun "echo -e 'q\n' | checkpolicy -Mdb ${ACTIVE_POLICY} | tee ${OUTPUT_FILE}"
        rlRun "grep -qi -e error -e ebitmap -e 'not match' ${OUTPUT_FILE}" 1
        if rlIsRHEL "<9" ; then
            LIST="minimum mls targeted"
        else
            LIST="mls targeted"
        fi
        for POLICY_TYPE in $LIST ; do
            if [ ! -e /etc/selinux/${POLICY_TYPE}/policy/policy.* ] ; then
                continue
            fi
            rlRun "echo -e 'q\n' | checkpolicy -Mdb /etc/selinux/${POLICY_TYPE}/policy/policy.* | tee ${OUTPUT_FILE}"
            rlRun "grep -qi -e error -e ebitmap -e 'not match' ${OUTPUT_FILE}" 1
        done
    rlPhaseEnd

    rlPhaseStartTest "bz#1328966 + bz#1328979"
        if rlIsRHEL 5 6 ; then
            ACTIVE_POLICY_TREE="/selinux"
        else # RHEL-7 and above
            ACTIVE_POLICY_TREE="/sys/fs/selinux"
        fi
        MIN_VERSION="15"
        MAX_VERSION=`find /etc/selinux/ -name policy.?? | cut -d / -f 6 | cut -d . -f 2 | head -n 1`
        if rlIsRHEL "<9" ; then
            LIST="minimum mls targeted"
        else
            LIST="mls targeted"
        fi
        for POLICY_TYPE in $LIST ; do
            if rlIsRHEL 5 6 ; then
                VERSIONS=`seq ${MIN_VERSION} 1 ${MAX_VERSION}`
            else
                # some versions are skipped because of BZ#1328979
                VERSIONS=`seq ${MIN_VERSION} 1 ${MAX_VERSION} | grep -v -e 19 -e 20 -e 21 -e 22 -e 23`
            fi
            for CUR_VERSION in ${VERSIONS} ; do
                rlRun "rm -f policy.out"
                rlWatchdog "checkpolicy -b -M -c ${CUR_VERSION} -o policy.out /etc/selinux/${POLICY_TYPE}/policy/policy.${MAX_VERSION}" 15
                if [ -s policy.out ] ; then
                    rlRun "seinfo policy.out 2>&1 | tee ${OUTPUT_FILE}"
                    rlRun "grep -i -e \"policy version.*${CUR_VERSION}\" -e \"unable to open policy\" ${OUTPUT_FILE}"
                else
                    rlRun "ls -l policy.out"
                fi
            done
        done
    rlPhaseEnd

    rlPhaseStartTest "handle unknown classes and perms"
        for ACTION in allow deny reject ; do
            rlRun "rm -f policy.out"
            rlWatchdog "checkpolicy -M -U ${ACTION} -o policy.out policy.conf.from.secilc" 15
            if [ -s policy.out ] ; then
                rlRun "echo -e 'U\nq\n' | sedispol policy.out 2>&1 | tee ${OUTPUT_FILE}"
                rlRun "grep -i \"${ACTION} unknown\" ${OUTPUT_FILE}"
            else
                rlFail "policy.out is empty or was not created"
            fi
        done
    rlPhaseEnd

    if ! rlIsRHEL '<=8.1'; then
    rlPhaseStartTest "sorting ocontexts"
        # check -S option in --help
        rlRun "checkpolicy --help >$OUTPUT_FILE" 0,1
        rlRun "cat $OUTPUT_FILE"
        rlAssertGrep "\[-S\]" $OUTPUT_FILE

        if [ -e "/usr/share/man/man8/checkmodule.8.gz" ];then
            # check -S option in man page
            rlRun "PAGER=cat man checkpolicy >$OUTPUT_FILE"
            rlRun "cat $OUTPUT_FILE"
            rlAssertGrep "\[-S\]" $OUTPUT_FILE
        fi

        # run checkpolicy with the -S option
        rlWatchdog "checkpolicy -S -M -o policy.out policy.conf.from.secilc" 15
        rlRun "seinfo policy.out"
    rlPhaseEnd
    fi

    rlPhaseStartTest "Test checkpolicy cil option"
        # check -C option without input file
        rlRun "checkpolicy -C 2>&1 | grep \"unable to open policy.conf\""
        # check -C option with policy.conf file
        rlRun "checkpolicy -C -M -o policy.cil policy.conf.from.secilc"
        rlAssertGrep "(allow [a-z]*_.* [a-z]*_.* ([a-z]* ([a-z]*)))" policy.cil
        # check -C option with policy binary file
        rlRun "checkpolicy -C -M -o policy.cil2 -b /sys/fs/selinux/policy"
        rlAssertGrep "(allow [a-z]*_.* [a-z]*_.* ([a-z]* ([a-z]*)))" policy.cil2
    rlPhaseEnd

    if rlIsRHEL '>=9' ; then
    rlPhaseStartTest "Test checkpolicy optimize option"
        # check -O option without input file
        rlRun "checkpolicy -O 2>&1 | grep \"unable to open policy.conf\""
        # Create optimized -O binary with policy.conf file
        rlRun "checkpolicy -O -M -o policy.opt policy.conf.from.secilc"
        rlRun "seinfo policy.opt"
        # Create regular binary with policy.conf file
        rlRun "checkpolicy -M -o policy.reg policy.conf.from.secilc"
        rlRun "seinfo policy.reg"
        # Compare size of optimized and regular binary
        OPT1=`stat -c %s policy.opt`
        REG1=`stat -c %s policy.reg`
        rlAssertGreater "Test if regular file size is higher than optimized file" $REG1 $OPT1
        # Compare allow rule counts between optimized and regular binary
        rlRun "seinfo policy.opt > /tmp/optfile"
        OPT_CNT=`grep Allow: /tmp/optfile | tr -s ' ' | sed 's/^ //' | cut -d ' ' -f2`
        rlRun "seinfo policy.reg > /tmp/regfile"
        REG_CNT=`grep Allow: /tmp/regfile | tr -s ' ' | sed 's/^ //' | cut -d ' ' -f2`
        rlAssertGreater "Regular file has higher allow rule than optimized file" $REG_CNT $OPT_CNT
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rm -f ${OUTPUT_FILE} policy.out policy.cil policy.cil2 policy.opt policy.reg /tmp/optfile /tmp/regfile
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

