#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/power-profiles-daemon-and-similar
#   Description: SELinux interferes with power-profiles-daemon and related programs
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
FILE_PATH="/usr/libexec/power-profiles-daemon"
SERVICE_PACKAGE="power-profiles-daemon"
SERVICE_NAME="power-profiles-daemon"
PROCESS_NAME="power-profiles-daemon"
if seinfo -t | grep -q powerprofile ; then
    PROCESS_CONTEXT="powerprofiles_t"
    FILE_CONTEXT="powerprofiles_exec_t"
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
        if rpm -q tuned-ppd ; then
            rlRun "yum -y remove tuned-ppd"
        fi
        rlRun "yum -y install ${SERVICE_PACKAGE}"
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qf ${FILE_PATH}"

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ( rlIsRHEL 9 && rlIsRHEL ">9.5" ) || rlIsCentOS 9 ; then
    rlPhaseStartTest "RHEL-61117"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSESearchRule "allow powerprofiles_t powerprofiles_t : capability2 { bpf } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "RHEL-100718"
        if [ -d /sys/devices/system/cpu/cpufreq ] ; then
            for CUR_FILE in `find /sys/devices/system/cpu/cpufreq -type f -name energy_performance_preference` ; do
                CUR_TYPE=`secon --type --file ${CUR_FILE}`
                rlSESearchRule "allow powerprofiles_t $CUR_TYPE : file { write } [ ]"
            done
        fi
        rlSESearchRule "allow powerprofiles_t fs_t : filesystem { getattr } [ ]"
    rlPhaseEnd

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "powerprofilesctl list"
        rlRun "powerprofilesctl list-holds"
        rlRun "powerprofilesctl version"
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        ORIG_PROFILE=`powerprofilesctl get`
        if echo ${ORIG_PROFILE} | grep -q balanced ; then
            rlRun "powerprofilesctl set power-saver" 0,1
        else
            rlRun "powerprofilesctl set balanced" 0,1
        fi
        sleep 2
        rlRun "powerprofilesctl get"
        rlRun "powerprofilesctl set ${ORIG_PROFILE}"
        sleep 2
        rlRun "powerprofilesctl launch echo" 0,1
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

