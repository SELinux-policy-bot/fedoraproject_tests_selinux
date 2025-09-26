#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/iio-sensor-proxy-and-similar
#   Description: SELinux interferes with iio-sensor-proxy and related programs
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
FILE_PATH="/usr/libexec/iio-sensor-proxy"
SERVICE_NAME="iio-sensor-proxy"
PROCESS_NAME="iio-sensor-proxy"
if seinfo -t | grep -q iiosensor ; then
    PROCESS_CONTEXT="iiosensorproxy_t"
    FILE_CONTEXT="iiosensorproxy_exec_t"
else
    PROCESS_CONTEXT="unconfined_service_t"
    FILE_CONTEXT="bin_t"
fi

rlJournalStart
    if rlIsRHEL 7 || rlIsCentOS 7 ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qf ${FILE_PATH}"

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/systemd/system/iio-sensor-proxy.service
        rlServiceStart gdm

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if seinfo -t | grep -q iiosensorproxy ; then
    rlPhaseStartTest "RHEL-17346 + RHEL-62355 + RHEL-70850"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSESearchRule "allow xdm_t iiosensorproxy_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow iiosensorproxy_t xdm_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow iiosensorproxy_t iiosensorproxy_t : capability2 { bpf } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "cp -f /usr/lib/systemd/system/iio-sensor-proxy.service /etc/systemd/system/"
        rlRun "sed -i 's/^.*Environment=.*$/Environment=FAKE_COMPASS=1/' /etc/systemd/system/iio-sensor-proxy.service"
        rlRun "systemctl daemon-reload"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlRun "sed -i 's/^.*Environment=.*$/Environment=FAKE_LIGHT_SENSOR=1/' /etc/systemd/system/iio-sensor-proxy.service"
        rlRun "systemctl daemon-reload"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "gdbus introspect --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy"
        rlWatchdog "monitor-sensor --all" 10
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlRun "systemctl daemon-reload"
        rlServiceRestore ${SERVICE_NAME}
        rlServiceRestore gdm
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

