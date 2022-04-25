#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-rfkill-and-similar
#   Description: SELinux interferes with systemd-rfkill and related programs
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
FILE_PATH="/usr/lib/systemd/systemd-rfkill"
FILE_CONTEXT="systemd_rfkill_exec_t"
SERVICE_PACKAGE="systemd-udev"
SERVICE_NAME="systemd-rfkill"
PROCESS_NAME="systemd-rfkill"
PROCESS_CONTEXT="systemd_rfkill_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}
        rlRun "rpm -qa kernel\*"
        rlRun "uname -r"

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#1290255"
        rlSEMatchPathCon "/var/lib/systemd" "init_var_lib_t"
        rlSESearchRule "allow systemd_rfkill_t init_var_lib_t : dir { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1309839"
        rlSEMatchPathCon "/var/lib/systemd/rfkill" "systemd_rfkill_var_lib_t"
        rlSEMatchPathCon "/var/lib/systemd/rfkill/something" "systemd_rfkill_var_lib_t"
        rlSESearchRule "allow systemd_rfkill_t systemd_rfkill_var_lib_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1319499 + bz#1661724"
        rlSEMatchPathCon "/var/lib/systemd/rfkill/something" "systemd_rfkill_var_lib_t"
        rlSESearchRule "allow systemd_rfkill_t systemd_rfkill_var_lib_t : file { unlink } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1388669"
        rlSEMatchPathCon "/dev/kmsg" "kmsg_device_t"
        rlSESearchRule "allow systemd_rfkill_t kmsg_device_t : chr_file { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1543650 + bz#1554838"
        rlSESearchRule "allow systemd_rfkill_t kernel_t : system { module_request } [ domain_kernel_load_modules ]"
        rlSESearchRule "dontaudit systemd_rfkill_t kernel_t : system { module_request } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1557595"
        rlSESearchRule "allow systemd_rfkill_t systemd_rfkill_t : capability { sys_admin } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1638981"
        rlSEMatchPathCon "/run/systemd/journal/socket" "syslogd_var_run_t"
        rlSESearchRule "allow systemd_rfkill_t syslogd_var_run_t : sock_file { write } [ ]"
        rlSESearchRule "allow systemd_rfkill_t syslogd_t : unix_dgram_socket { sendto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        if systemctl is-enabled ${SERVICE_NAME} | grep -q masked ; then
            rlRun "systemctl unmask ${SERVICE_NAME}"
        fi
        rlRun "modprobe rfkill"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var" 0-255
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

