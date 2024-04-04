#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/usbguard-daemon-and-similar
#   Description: SELinux interferes with usbguard and related programs
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
FILE_PATH="/usr/sbin/usbguard-daemon"
FILE_CONTEXT="usbguard_exec_t"
SERVICE_PACKAGE="usbguard"
SERVICE_NAME="usbguard"
PROCESS_NAME="usbguard-daemon"
PROCESS_CONTEXT="usbguard_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qa ${SERVICE_PACKAGE}\*"

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow
        rlFileBackup /etc/usbguard/usbguard-daemon.conf

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined ${PROCESS_CONTEXT} ; then
    rlPhaseStartTest "bz#1808527"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow init_t ${FILE_CONTEXT} : file { getattr open read execute } [ ]"
        rlSESearchRule "allow init_t ${PROCESS_CONTEXT} : process { transition } [ ]"
        rlSESearchRule "type_transition init_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} [ ]"
        rlSESearchRule "allow usbguard_t usbguard_t : netlink_audit_socket { create nlmsg_relay } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1840265"
        # according to logged AVCs, target class is file instead of chr_file
        # all these files are created by systemd under /tmp/namespace-dev-*/
        rlSESearchRule "allow init_t ptmx_t : file { create mounton } [ ]"
        rlSESearchRule "allow init_t null_device_t : file { create mounton } [ ]"
        rlSESearchRule "allow init_t zero_device_t : file { create mounton } [ ]"
        rlSESearchRule "allow init_t random_device_t : file { create mounton } [ ]"
        rlSESearchRule "allow init_t urandom_device_t : file { create mounton } [ ]"
        rlSESearchRule "allow init_t devtty_t : file { create mounton } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlRun "semodule -lfull | grep usbguard"
        rlRun "sed -i \"s/^AuditBackend=.*$/AuditBackend=LinuxAudit/\" /etc/usbguard/usbguard-daemon.conf"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
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

