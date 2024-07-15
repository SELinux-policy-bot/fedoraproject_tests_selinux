#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/libvirt-dbus-and-similar
#   Description: SELinux interferes with libvirt-dbus and related programs
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
FILE_PATH="/usr/sbin/libvirt-dbus"
SERVICE_PACKAGE="libvirt-dbus"
SERVICE_NAME="libvirt-dbus"
PROCESS_NAME="libvirt-dbus"

if seinfo -t | grep -q virt_dbus ; then
    FILE_CONTEXT="virt_dbus_exec_t"
    PROCESS_CONTEXT="virt_dbus_t"
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
        rlRun "yum -y install libvirt\* --skip-broken"

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-46893"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSESearchRule "allow virt_dbus_t virtqemud_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow virtqemud_t virt_dbus_t : dir { search } [ ]"
        rlSESearchRule "allow virtqemud_t virt_dbus_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- communication with other virt* services"
        for VIRT_SERVICE in virtinterfaced virtlxcd virtnetworkd virtnodedevd virtnwfilterd virtproxyd virtqemud virtsecretd virtstoraged virtvboxd ; do
            if [ -f /usr/lib/systemd/system/${VIRT_SERVICE}.service ] ; then
                rlRun "service ${VIRT_SERVICE} start"
            fi
        done

        AVAIL_DAEMONS="QEMU"
        if [ -f /usr/lib/systemd/system/virtlxcd.service ] ; then
            AVAIL_DAEMONS="LXC QEMU"
        fi

        for DAEMON in ${AVAIL_DAEMONS} ; do
            for METHOD in ListDomains ListInterfaces ListNWFilters ListNetworks ListNodeDevices ListSecrets ListStoragePools ; do
                rlRun "busctl call org.libvirt /org/libvirt/${DAEMON} org.libvirt.Connect ${METHOD} u 0" 0,1
            done
        done

        for VIRT_SERVICE in virtinterfaced virtlxcd virtnetworkd virtnodedevd virtnwfilterd virtproxyd virtqemud virtsecretd virtstoraged virtvboxd ; do
            if [ -f /usr/lib/systemd/system/${VIRT_SERVICE}.service ] ; then
                rlRun "service ${VIRT_SERVICE} stop"
            fi
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

