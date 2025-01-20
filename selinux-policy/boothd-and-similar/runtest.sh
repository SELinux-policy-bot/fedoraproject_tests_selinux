#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/boothd-and-similar
#   Description: SELinux interferes with boothd and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/sbin/boothd"
SERVICE_PACKAGE="booth-arbitrator"
SERVICE_NAME="booth-arbitrator"
PROCESS_NAME="boothd"
if seinfo -t | grep -q boothd ; then
    FILE_CONTEXT="boothd_exec_t"
    PROCESS_CONTEXT="boothd_t"
else
    FILE_CONTEXT="bin_t"
    PROCESS_CONTEXT="unconfined_service_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/booth/booth.conf
        rlRun "service systemd-machined start"

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if seinfo -t | grep -q boothd ; then
    rlPhaseStartTest "RHEL-45907"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/run/systemd/userdb" "systemd_userdbd_runtime_t"
        rlSESearchRule "allow boothd_t systemd_userdbd_runtime_t : dir { read } [ ]"
        rlSESearchRule "allow boothd_t systemd_userdbd_runtime_t : sock_file { write } [ ]"
        rlSESearchRule "allow boothd_t systemd_userdbd_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-57104 + RHEL-58060"
        rlSESearchRule "allow boothd_t kernel_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-75471"
        rlSESearchRule "allow boothd_t systemd_machined_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        IF_NAME=`route | grep default | awk '{ print $8 }'`
        IP_ADDRESS=`ip addr show ${IF_NAME} | grep 'inet ' | cut -d / -f 1 | awk '{ print $2 }' | head -n 1`
        rlRun "cp -f /usr/share/doc/booth/booth.conf.example /etc/booth/booth.conf"
        rlRun "sed -i 's/^arbitrator=.*$/arbitrator=\"${IP_ADDRESS}\"/' /etc/booth/booth.conf"
        rlRun "grep ^arbitrator /etc/booth/booth.conf"
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "booth list"
        rlRun "booth status"
        rlRun "booth peers"
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
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

