#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/icecast-and-similar
#   Description: SELinux interferes with icecast and related programs
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
FILE_PATH="/usr/bin/icecast"
FILE_CONTEXT="icecast_exec_t"
SERVICE_PACKAGE="icecast"
SERVICE_NAME="icecast"
PROCESS_NAME="icecast"
PROCESS_CONTEXT="icecast_t"

rlJournalStart
    if rlIsRHEL ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/icecast.xml

        rlRun "setenforce 1"
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#894387"
        rlSEMatchPathCon "/usr/bin/icecast" "icecast_exec_t"
        rlSEMatchPortCon tcp 8080 http_cache_port_t
        rlSESearchRule "allow icecast_t http_cache_port_t : tcp_socket { name_bind } [ icecast_use_any_tcp_ports ]"
        if rlIsRHEL 6 ; then
            rlSESearchRule "dontaudit icecast_t tmp_t : dir { read }"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#2156763"
        rlSEMatchPathCon "/usr/bin/icecast" "icecast_exec_t"
        rlSEMatchPathCon "/var/log/icecast" "icecast_log_t"
        rlSEMatchPathCon "/var/log/icecast/error.log" "icecast_log_t"
        rlSESearchRule "allow icecast_t icecast_log_t : dir { remove_name } [ ]"
        rlSESearchRule "allow icecast_t icecast_log_t : file { rename } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- bz#894387"
        if rlIsRHEL 5 6 ; then
            rlRun "setsebool icecast_connect_any on"
        else
            rlRun "setsebool icecast_use_any_tcp_ports on"
        fi
        rlRun "sed -i \"s|8000|8080|\" /etc/icecast.xml"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "sed -i 's|^\(.*logsize>\).*\(</logsize.*\)$|\11\2|' /etc/icecast.xml"
        rlRun "grep logsize /etc/icecast.xml"
        rlRun "sed -i 's|^.*\(<logarchive.*logarchive>\).*$|\1|' /etc/icecast.xml"
        rlRun "grep logarchive /etc/icecast.xml"
        rlRun "restorecon -Rv /var /run -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
        if rlIsRHEL 5 6 ; then
            rlRun "setsebool icecast_connect_any off"
        else
            rlRun "setsebool icecast_use_any_tcp_ports off"
        fi
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

