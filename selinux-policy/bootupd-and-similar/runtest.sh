#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bootupd-and-similar
#   Description: SELinux interferes with the bootupd service and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/libexec/bootupd"
SERVICE_PACKAGE="bootupd"
SERVICE_NAME="bootupd"
PROCESS_NAME="bootupd"
if seinfo -t | grep -q bootupd ; then
    FILE_CONTEXT="bootupd_exec_t"
    PROCESS_CONTEXT="bootupd_t"
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

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#2029478 + bz#2044508"
        # both BZs were closed as WONTFIX, but the test is flexible enough
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        BOOLEANS="[ ]"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#2218106"
        rlSEMatchPathCon "/usr/libexec/bootupd" "${FILE_CONTEXT}"
        rlRun "ls -RlZ /boot/efi"
        rlSESearchRule "allow ${PROCESS_CONTEXT} dosfs_t : dir { getattr search } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-36289 + RHEL-39514"
        rlSEMatchPathCon "/usr/libexec/bootupd" "${FILE_CONTEXT}"
        if [ -d /sys/firmware/efi/efivars ] ; then
            rlRun "ls -RlZ /sys/firmware/efi/efivars"
        fi
        rlSESearchRule "allow ${PROCESS_CONTEXT} efivarfs_t : dir { getattr search } [ ]"
    rlPhaseEnd

    if [ -f /usr/lib/systemd/system/bootupd.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for OSes where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlRun "systemctl start ${SERVICE_NAME}.socket"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
        rlRun "systemctl stop ${SERVICE_NAME}.socket"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/bootupd.socket ] ; then
    rlPhaseStartTest "real scenario -- ${SERVICE_NAME}.socket"
        rlRun "systemctl enable ${SERVICE_NAME}.socket"
        rlRun "systemctl start ${SERVICE_NAME}.socket"
        sleep 1
        rlRun "bootupctl status" 0,1
        rlRun "bootupctl validate" 0,1
        rlRun "lsblk"
        rlRun "systemctl stop ${SERVICE_NAME}.socket"
        rlRun "systemctl disable ${SERVICE_NAME}.socket"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

