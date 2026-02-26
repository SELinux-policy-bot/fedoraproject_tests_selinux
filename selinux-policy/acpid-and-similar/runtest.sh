#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/acpid-and-similar
#   Description: SELinux interferes with acpid and related programs
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
FILE_PATH="/usr/sbin/acpid"
FILE_CONTEXT="apmd_exec_t"
SERVICE_PACKAGE="acpid"
SERVICE_NAME="acpid"
PROCESS_NAME="acpid"
PROCESS_CONTEXT="apmd_t"

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
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow initrc_t ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow initrc_t ${PROCESS_CONTEXT} : process { transition }"
        rlSESearchRule "type_transition initrc_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#995898"
        rlSEMatchPathCon "/usr/sbin/acpid" "apmd_exec_t"
        rlSEMatchPathCon "/usr/lib/systemd/system/poweroff.target" "power_unit_file_t"
        rlSESearchRule "allow apmd_t init_t : dbus { send_msg }"
        rlSESearchRule "allow init_t apmd_t : dbus { send_msg }"
        rlSESearchRule "allow apmd_t power_unit_file_t : service { start }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1358478 + bz#1468548"
        rlSEMatchPathCon "/usr/sbin/acpid" "apmd_exec_t"
        rlSESearchRule "allow apmd_t apmd_t : netlink_generic_socket { create setopt bind } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1622417 + bz#1623342"
        rlSEMatchPathCon "/usr/sbin/acpid" "apmd_exec_t"
        rlSEMatchPathCon "/dev/input/event20" "event_device_t"
        rlSEMatchPathCon "/dev/input/event21" "event_device_t"
        rlSEMatchPathCon "/dev/input/event22" "event_device_t"
        rlSEMatchPathCon "/dev/input/event23" "event_device_t"
        rlSEMatchPathCon "/dev/input/event24" "event_device_t"
        rlSEMatchPathCon "/dev/input/event25" "event_device_t"
        rlSEMatchPathCon "/dev/input/event26" "event_device_t"
        rlSEMatchPathCon "/dev/input/event27" "event_device_t"
        rlSEMatchPathCon "/dev/input/event28" "event_device_t"
        rlSEMatchPathCon "/dev/input/event29" "event_device_t"
        rlSEMatchPathCon "/dev/input/event30" "event_device_t"
        rlSESearchRule "allow apmd_t event_device_t : chr_file { getattr open read } [ ]"
        for I in `seq 20 1 30` ; do
            rlRun "sesearch -T -s init_t -t device_t -c chr_file | grep \"event_device_t.*event$I\""
            rlRun "sesearch -T -s kernel_t -t device_t -c chr_file | grep \"event_device_t.*event$I\""
            rlRun "sesearch -T -s udev_t -t device_t -c chr_file | grep \"event_device_t.*event$I\""
        done
    rlPhaseEnd
    fi

    if seinfo --common file -x | grep -q watch ; then
    rlPhaseStartTest "bz#1932294"
        rlSEMatchPathCon "/usr/sbin/acpid" "apmd_exec_t"
        rlSEMatchPathCon "/dev/input" "device_t"
        rlSESearchRule "allow apmd_t device_t : dir { watch } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
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

