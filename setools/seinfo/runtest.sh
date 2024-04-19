#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/setools/Sanity/seinfo
#   Description: Does seinfo work well? Does it support all features?
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="setools"

rlJournalStart
    rlPhaseStartSetup
        if rlIsRHEL 5 ; then
            rlAssertRpm ${PACKAGE}
        else
            rlAssertRpm ${PACKAGE}-console
        fi
        rlAssertRpm selinux-policy
        rlAssertRpm selinux-policy-targeted
        SHORT_OUTPUT=`mktemp`
        LONG_OUTPUT=`mktemp`
    rlPhaseEnd

    if seinfo --version | grep -q '3\.3' ; then
    rlPhaseStartTest "bz#499247 + bz#584286"
        rlRun "seinfo"
        rlRun "seinfo --version"
        rlRun "seinfo --stats"
        for CLASS in "capability" ; do
            rlRun "SIMPLE_COUNT=\`seinfo -c${CLASS} | wc -l\`"
            rlAssertEquals "the output without details should 1 line long" ${SIMPLE_COUNT} 1
            rlRun "EXPANDED_COUNT=\`seinfo -x -c${CLASS} | wc -l\`"
            rlAssertGreater "the output with details should be more than 1 line long" ${EXPANDED_COUNT} 1
        done

        for TYPE in "root_t" ; do
            rlRun "SIMPLE_COUNT=\`seinfo -t${TYPE} | wc -l\`"
            rlAssertEquals "the output without details should 1 line long" ${SIMPLE_COUNT} 1
            rlRun "EXPANDED_COUNT=\`seinfo -x -t${TYPE} | wc -l\`"
            rlAssertGreater "the output with details should be more than 1 line long" ${EXPANDED_COUNT} 1
        done

        if ! rlIsRHEL 5 ; then
            ATTRIBUTE="domain"
        else
            ATTRIBUTE="@ttr0135"
        fi
        rlRun "SIMPLE_COUNT=\`seinfo -a${ATTRIBUTE} | wc -l\`"
        rlAssertEquals "the output without details should 1 line long" ${SIMPLE_COUNT} 1
        rlRun "EXPANDED_COUNT=\`seinfo -x -a${ATTRIBUTE} | wc -l\`"
        rlAssertGreater "the output with details should be more than 1 line long" ${EXPANDED_COUNT} 1

        for ROLE in "sysadm_r" ; do
            rlRun "SIMPLE_COUNT=\`seinfo -r${ROLE} | wc -l\`"
            rlAssertEquals "the output without details should 1 line long" ${SIMPLE_COUNT} 1
            rlRun "EXPANDED_COUNT=\`seinfo -x -r${ROLE} | wc -l\`"
            rlAssertGreater "the output with details should be more than 1 line long" ${EXPANDED_COUNT} 1
        done

        for USER in "root" ; do
            rlRun "SIMPLE_COUNT=\`seinfo -u${USER} | wc -l\`"
            rlAssertEquals "the output without details should 1 line long" ${SIMPLE_COUNT} 1
            rlRun "EXPANDED_COUNT=\`seinfo -x -u${USER} | wc -l\`"
            rlAssertGreater "the output with details should be more than 1 line long" ${EXPANDED_COUNT} 1
        done

        for BOOLEAN in "ftpd_connect_db" ; do
            rlRun "SIMPLE_COUNT=\`seinfo -b${BOOLEAN} | wc -c\`"
            rlAssertGreater "the output without details should be short" ${SIMPLE_COUNT} 10
            rlRun "EXPANDED_COUNT=\`seinfo -x -b${BOOLEAN} | wc -c\`"
            rlAssertGreater "the output with details should be longer" ${EXPANDED_COUNT} ${SIMPLE_COUNT}
        done

        if rlIsRHEL 5 ; then
            for OPTION_PAIR in \
            "-c|--classes" \
            "-t|--types" \
            "-a|--attribs" \
            "-r|--roles" \
            "-u|--users" \
            "-b|--boolean" \
            "-S|--sensitivities" \
            "-C|--categories" \
            "-f|--fs_use" \
            "-g|--genfscon" \
            "-n|--netifcon" \
            "-o|--nodecon" \
            "-p|--portcon" \
            "-i|--initialsid" ; do
                SHORT_OPTION=`echo ${OPTION_PAIR} | cut -d '|' -f 1`
                rlRun "seinfo ${SHORT_OPTION} >& ${SHORT_OUTPUT}"
                LONG_OPTION=`echo ${OPTION_PAIR} | cut -d '|' -f 2`
                rlRun "seinfo ${LONG_OPTION} >& ${LONG_OUTPUT}"
                rlRun "diff ${SHORT_OUTPUT} ${LONG_OUTPUT} >& /dev/null"
            done
        else
            for OPTION_PAIR in \
            "-c|--class" \
            "-t|--type" \
            "-a|--attribute" \
            "-r|--role" \
            "-u|--user" \
            "-b|--bool" ; do
                SHORT_OPTION=`echo ${OPTION_PAIR} | cut -d '|' -f 1`
                rlRun "seinfo ${SHORT_OPTION} >& ${SHORT_OUTPUT}"
                LONG_OPTION=`echo ${OPTION_PAIR} | cut -d '|' -f 2`
                rlRun "seinfo ${LONG_OPTION} >& ${LONG_OUTPUT}"
                rlRun "diff ${SHORT_OUTPUT} ${LONG_OUTPUT} >& /dev/null"
            done
        fi
    rlPhaseEnd
    fi

    if false ; then # both bugs were closed as WONTFIX
    rlPhaseStartTest "bz#649699 + bz#650092"
        for SHORT_OPTION in "-c" "-t" "-a" "-r" "-u" "-b" ; do
            rlRun "seinfo ${SHORT_OPTION}xyz" 1-255
        done
        for LONG_OPTION in "--class" "--sensitivity" "--category" "--type" "--attribute" \
            "--role" "--user" "--bool" "--constrain" "--initialsid" "--fs_use" "--genfscon" \
            "--netifcon" "--nodecon" "--all" "--portcon --protocol" "--expand" "--stats" \
            "--version" "--help"; do
            rlRun "seinfo ${LONG_OPTION}=xyz" 1-255
        done
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#739628"
        rlRun "seinfo -r | grep -v -e Roles: -e _r$ -e ^$" 1
        rlRun "seinfo -u | grep -v -e Users: -e _u$ -e ^$ -e root$" 1
        rlRun "seinfo -t | grep -v -e Types: -e _t$ -e ^$" 1
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#928705 + bz#1581761"
        rlRun "seinfo -tspamc_t -x | grep -i alias"
        rlRun "seinfo -tspamc_t -x | grep spamc_t"
        rlRun "seinfo -tspamc_t -x | grep spamassassin_t"
        rlRun "seinfo -tspamassassin_t -x | grep -i alias"
        rlRun "seinfo -tspamassassin_t -x | grep spamassassin_t"
        rlRun "seinfo -tspamassassin_t -x | grep -i spamc_t"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1029837"
        # there is a difference when seinfo analyzes the policy file stored under /etc/selinux and the active policy stored in the SELinux file-system
        if rlIsRHEL 5 6 ; then
            SELINUX_FS="/selinux"
        else
            SELINUX_FS="/sys/fs/selinux"
        fi
        rlRun "seinfo ${SELINUX_FS}/policy"
        for POLICY_TYPE in minimum mls targeted ; do
            if [ -f /etc/selinux/${POLICY_TYPE}/policy/policy.* ] ; then
                rlRun "seinfo /etc/selinux/${POLICY_TYPE}/policy/policy.*"
            fi
        done
    rlPhaseEnd

    if seinfo --version | grep '^4\.' ; then
    rlPhaseStartTest "additional v.4 features in comparison to v.3"
        for OPTION in "common" "default" "typebounds" "validatetrans" ; do
            rlRun "seinfo --${OPTION}"
            rlRun "seinfo --${OPTION} | grep -i ${OPTION}"
        done
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rm -f ${SHORT_OUTPUT}
        rm -f ${LONG_OUTPUT}
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

