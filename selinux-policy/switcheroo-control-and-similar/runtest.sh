#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/switcheroo-control-and-similar
#   Description: SELinux interferes with switcheroo-control and related programs
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
FILE_PATH="/usr/libexec/switcheroo-control"
SERVICE_PACKAGE="switcheroo-control"
SERVICE_NAME="switcheroo-control"
PROCESS_NAME="switcheroo-control"
if seinfo -t | grep -q switcheroo ; then
    PROCESS_CONTEXT="switcheroo_control_t"
    FILE_CONTEXT="switcheroo_control_exec_t"
else
    PROCESS_CONTEXT="unconfined_service_t"
    FILE_CONTEXT="bin_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlServiceStart gdm

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if seinfo -t | grep -q switcheroo ; then
    rlPhaseStartTest "RHEL-24268"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSEMatchPathCon "/run/udev/" "udev_var_run_t"
        rlSEMatchPathCon "/run/dbus/" "system_dbusd_var_run_t"
        rlSEMatchPathCon "/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSESearchRule "allow switcheroo_control_t udev_var_run_t : dir { search } [ ]"
        rlSESearchRule "allow switcheroo_control_t switcheroo_control_t : netlink_kobject_uevent_socket { create setopt bind getattr } [ ]"
        rlSESearchRule "allow switcheroo_control_t switcheroo_control_t : capability2 { bpf } [ ]"
        rlSESearchRule "allow switcheroo_control_t sysfs_t : dir { read } [ ]"
        rlSESearchRule "allow switcheroo_control_t sysfs_t : lnk_file { getattr read } [ ]"
        rlSESearchRule "allow switcheroo_control_t sysfs_t : file { getattr open read } [ ]"
        rlSESearchRule "allow switcheroo_control_t system_dbusd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow switcheroo_control_t system_dbusd_var_run_t : sock_file { write } [ ]"
        rlSESearchRule "allow switcheroo_control_t system_dbusd_var_run_t : dir { search } [ ]"
        rlSESearchRule "allow switcheroo_control_t system_dbusd_t : dbus { acquire_svc send_msg } [ ]"
        rlSESearchRule "allow system_dbusd_t switcheroo_control_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow unconfined_t switcheroo_control_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow switcheroo_control_t unconfined_t : dbus { send_msg } [ ]"
    rlPhaseEnd

        if ! rlIsRHEL "<9.7" && ! ( rlIsRHEL 10 && rlIsRHEL "<10.1" ); then
        rlPhaseStartTest "RHEL-93335 + RHEL-93535"
            rlSESearchRule "allow xdm_t switcheroo_control_t : dbus { send_msg } [ ]"
            rlSESearchRule "allow switcheroo_control_t xdm_t : dbus { send_msg } [ ]"
        rlPhaseEnd
        fi
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "switcherooctl version"
        rlRun "switcherooctl list"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlRun "touch ./empty-file"
        rlRun "switcherooctl launch ./empty-file" 0,1
        rlRun "rm -f ./empty-file"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

