#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/rtkit-daemon-and-similar
#   Description: the service was running as initrc_t, now it is confined by SELinux
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/libexec/rtkit-daemon"
FILE_CONTEXT="rtkit_daemon_exec_t"
SERVICE_PACKAGE="rtkit"
SERVICE_NAME="rtkit-daemon"
PROCESS_NAME="rtkit-daemon"
PROCESS_CONTEXT="rtkit_daemon_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
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
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow initrc_t ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow initrc_t ${PROCESS_CONTEXT} : process { transition }"
        rlSESearchRule "type_transition initrc_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1626982"
        rlSEMatchPathCon "/usr/libexec/rtkit-daemon" "rtkit_daemon_exec_t"
        rlSESearchRule "allow rtkit_daemon_t pulseaudio_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow pulseaudio_t rtkit_daemon_t : dbus { send_msg } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1703241 + bz#1720546"
        rlSEMatchPathCon "/usr/libexec/rtkit-daemon" "rtkit_daemon_exec_t"
        rlSESearchRule "allow rtkit_daemon_t sysadm_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow sysadm_t rtkit_daemon_t : dbus { send_msg } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "real scenario -- DBus service"
        DESTINATION="org.freedesktop.RealtimeKit1"
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
    rlPhaseEnd
    fi

    if rlIsFedora || rlIsRHEL ">8.3" ; then
    rlPhaseStartTest "bz#1873658"
        rlSESearchRule "allow rtkit_daemon_t rtkit_daemon_t : cap_userns { sys_ptrace } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1750024 + bz#1910507"
        # this bug has many duplicates among Fedora bugs
        rlSESearchRule "allow rtkit_daemon_t rtkit_daemon_t : cap_userns { sys_nice } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

