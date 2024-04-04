#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/accounts-daemon-and-similar
#   Description: SELinux interferes with accounts daemon and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/libexec/accounts-daemon"
FILE_CONTEXT="accountsd_exec_t"
SERVICE_PACKAGE="accountsservice"
SERVICE_NAME="accounts-daemon"
PROCESS_NAME="accounts-daemon"
PROCESS_CONTEXT="accountsd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]" # a boolean name
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition }"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
    rlPhaseEnd

    rlPhaseStartTest "bz#1456760 + bz#1518211"
        rlSEMatchPathCon "/usr/libexec/accounts-daemon" "accountsd_exec_t"
        rlSEMatchPathCon "/root" "admin_home_t"
        rlSESearchRule "dontaudit accountsd_t admin_home_t : dir { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1507089"
        rlSEMatchPathCon "/usr/libexec/accounts-daemon" "accountsd_exec_t"
        rlSESearchRule "allow accountsd_t accountsd_t : capability { dac_read_search } [ ]"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1595667"
        rlSEMatchPathCon "/usr/sbin/useradd" "useradd_exec_t"
        rlSESearchRule "allow accountsd_t useradd_exec_t : file { map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1792895 + bz#1821156"
        rlSESearchRule "allow accountsd_t realmd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow realmd_t accountsd_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1828809"
        for USER_TYPE in user_t staff_t sysadm_t xguest_t unconfined_t ; do
           rlSESearchRule "allow ${USER_TYPE} accountsd_t : dbus { send_msg } [ ]"
           rlSESearchRule "allow accountsd_t ${USER_TYPE} : dbus { send_msg } [ ]"
        done
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "real scenario -- DBus service"
        DESTINATION="org.freedesktop.Accounts"
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd
    fi

    if rlIsFedora ; then
    rlPhaseStartTest "bz#1806126, bz#1811407, bz#1815312, bz#1818696, bz#1819040, bz#1820978, bz#1820992, bz#1829013, bz#1829075, bz#1829128"
        rlSEMatchPathCon "/usr/libexec/accounts-daemon" "accountsd_exec_t"
        rlSESearchRule "dontaudit accountsd_t accountsd_t : capability { sys_nice } [ daemons_dontaudit_scheduling ]"
    rlPhaseEnd
    fi

    if seinfo --common file -x | grep -q watch ; then
    rlPhaseStartTest "bz#1928546 + bz#1933842 + bz#1935232"
        rlSEMatchPathCon "/usr/libexec/accounts-daemon" "accountsd_exec_t"
        rlSEMatchPathCon "/etc/gdm" "xdm_etc_t"
        rlSESearchRule "allow accountsd_t xdm_etc_t : dir { watch } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlRun "mkdir -p /etc/gdm"
        rlRun "restorecon -Rv /etc"
        rlRun "service realmd start" # helps to reproduce BZ#1792895
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

