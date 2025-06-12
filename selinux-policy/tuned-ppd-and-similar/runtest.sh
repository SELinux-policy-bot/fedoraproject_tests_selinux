#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/tuned-ppd-and-similar
#   Description: SELinux interferes with tuned-ppd and related programs
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
FILE_PATH="/usr/sbin/tuned-ppd"
SERVICE_PACKAGE="tuned-ppd"
SERVICE_NAME="tuned-ppd"
PROCESS_NAME="tuned-ppd"
if seinfo -t | grep -q tuned_ppd ; then
    PROCESS_CONTEXT="tuned_ppd_t"
    FILE_CONTEXT="tuned_ppd_exec_t"
else
    PROCESS_CONTEXT="unconfined_service_t"
    FILE_CONTEXT="bin_t"
fi

rlJournalStart
    if rlIsRHEL 7 8 || rlIsCentOS 7 8 ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        if rpm -q power-profiles-daemon ; then
            rlRun "yum -y remove power-profiles-daemon"
        fi
        rlRun "yum -y install ${SERVICE_PACKAGE}"
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/tuned/ppd_base_profile

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-69450 + RHEL-69526"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow init_t ${PROCESS_CONTEXT} : process { transition } [ ]"
        rlSESearchRule "type_transition init_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
        rlSESearchRule "allow init_t ${FILE_CONTEXT} : file { getattr open read execute } [ ]"
    rlPhaseEnd

    if rlSEDefined "xdm_t tuned_ppd_t" ; then
    rlPhaseStartTest "RHEL-85849"
        rlSESearchRule "allow xdm_t tuned_ppd_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow tuned_ppd_t xdm_t : dbus { send_msg } [ ]"
    rlPhaseEnd
    fi

    if rlSEDefined "tuned_ppd_t sssd_t" ; then
    rlPhaseStartTest "bz#2367076"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSESearchRule "allow tuned_ppd_t sssd_var_lib_t : sock_file { write } [ ]"
        rlSESearchRule "allow tuned_ppd_t sssd_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd
    fi

    if rlSEDefined "tuned_rw_etc_t tuned_ppd_t" ; then
    rlPhaseStartTest "bz#2359851 + bz#2360026 + bz#2361423 + bz#2367711"
        rlSEMatchPathCon "/etc/tuned" "tuned_etc_t"
        rlSEMatchPathCon "/etc/tuned/ppd_base_profile" "tuned_rw_etc_t"
        rlSESearchRule "type_transition tuned_ppd_t tuned_etc_t : file tuned_rw_etc_t ppd_base_profile"
        rlSESearchRule "allow tuned_ppd_t tuned_etc_t : dir { write add_name } [ ]"
        rlSESearchRule "allow tuned_ppd_t tuned_rw_etc_t : file { create write } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        if [ -f /usr/lib/systemd/system/gdm.service ] ; then
            rlRun "service gdm start"
            rlRun "service gdm status"
            sleep 2
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "busctl introspect net.hadess.PowerProfiles /org/freedesktop/UPower/PowerProfiles"
        rlRun "busctl introspect net.hadess.PowerProfiles /net/hadess/PowerProfiles"
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "ls -Z /etc/tuned/ppd_base_profile"
        rlRun "tuned-adm active"
        rlRun "rm -f /etc/tuned/ppd_base_profile"
        if tuned-adm active | grep -q powersave ; then
            rlRun "tuned-adm profile balanced"
        else
            rlRun "tuned-adm profile powersave"
        fi
        sleep 2
        rlRun "ls -lZ /etc/tuned/ppd_base_profile"
        rlRun "tuned-adm auto_profile"
        rlRun "ls -lZ /etc/tuned/ppd_base_profile"
        rlRun "tuned-adm verify"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
        if [ -f /usr/lib/systemd/system/gdm.service ] ; then
            sleep 2
            rlRun "service gdm stop"
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

