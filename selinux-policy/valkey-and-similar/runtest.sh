#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/valkey-and-similar
#   Description: SELinux interferes with valkey and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2025 Red Hat, Inc. All rights reserved.
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
FILE_CONTEXT="redis_exec_t"
SERVICE_PACKAGE="valkey"
SERVICE_NAME="valkey"
PROCESS_NAME="valkey-server"
PROCESS_CONTEXT="redis_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        if rpm -qa | grep -q valkey ; then
            rlAssertRpm ${SERVICE_PACKAGE}
            rlServiceStop valkey valkey-sentinel
        fi

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-102631"
        rlSEMatchPathCon `which valkey-server` ${FILE_CONTEXT}
        rlSEMatchPathCon `which valkey-sentinel` ${FILE_CONTEXT}
        rlSEMatchPathCon "/etc/valkey" "redis_conf_t"
        rlSEMatchPathCon "/etc/valkey/sentinel.conf" "redis_conf_t"
        rlSEMatchPathCon "/etc/valkey/valkey.conf" "redis_conf_t"
        rlSEMatchPathCon "/var/log/valkey" "redis_log_t"
        rlSEMatchPathCon "/var/lib/valkey" "redis_var_lib_t"
        rlSEMatchPathCon "/var/run/valkey" "redis_var_run_t"
        rlSEMatchPathCon "/usr/lib/systemd/system/valkey-sentinel.service" "redis_unit_file_t"
        rlSEMatchPathCon "/usr/lib/systemd/system/valkey.service" "redis_unit_file_t"
    rlPhaseEnd

    if rpm -q valkey-rdma >& /dev/null ; then
    rlPhaseStartTest "RHEL-154814 + RHEL-161115"
        rlSESearchRule "allow redis_t redis_t : netlink_rdma_socket { getattr create setopt bind } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- ${SERVICE_NAME} service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlWatchdog "valkey-cli --stat" 10
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    SERVICE_NAME="valkey-sentinel"
    PROCESS_NAME="valkey-sentinel"

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- ${SERVICE_NAME} service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlWatchdog "valkey-cli --stat -u valkey://default:PASSWORD@localhost:26379/0" 10
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlServiceRestore valkey valkey-sentinel
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

