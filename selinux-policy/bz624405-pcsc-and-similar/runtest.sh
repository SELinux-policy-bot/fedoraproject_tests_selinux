#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bz624405-pcsc-and-similar
#   Description: SELinux interferes with pcscd
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
SERVICE_NAME="pcscd"
PROCESS_CONTEXT="pcscd_t"
PROCESS_NAME="pcscd"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-mls
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm pcsc-lite

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#624405"
        rlSEMatchPathCon "/usr/sbin/pcscd" "pcscd_exec_t"
        if rlIsRHEL 5 ; then
            rlRun "ls -dZ /sys | grep :sysfs_t"
            rlRun "ls -dZ /sys/devices | grep :sysfs_t"
            rlSESearchRule "allow pcscd_t sysfs_t : dir { getattr search }"
        else
            rlSEMatchPathCon "/sys" "sysfs_t"
            rlSEMatchPathCon "/sys/devices" "sysfs_t"
            rlSESearchRule "allow pcscd_t sysfs_t : dir { getattr open read search }"
            rlSESearchRule "allow pcscd_t sysfs_t : file { getattr open read }"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#752453"
        rlSEMatchPathCon "/usr/sbin/pcscd" "pcscd_exec_t"
        rlSESearchRule "allow pcscd_t usb_device_t : chr_file { getattr read write }"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1605641"
        rlSEMatchPathCon "/usr/sbin/pcscd" "pcscd_exec_t"
        rlSESearchRule "dontaudit pcscd_t pcscd_t : capability { sys_admin }"
    rlPhaseEnd
    fi

    if rlIsFedora ; then
    rlPhaseStartTest "bz#1806129 + bz#1816787 + bz#1818759 + bz#1825182 + bz#1825188"
        rlSEMatchPathCon "/usr/sbin/pcscd" "pcscd_exec_t"
        rlSESearchRule "dontaudit pcscd_t pcscd_t : capability { sys_nice } [ daemons_dontaudit_scheduling ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1802423 + bz#1805719"
        rlSEMatchPathCon "/usr/sbin/pcscd" "pcscd_exec_t"
        rlSESearchRule "dontaudit pcscd_t pcscd_t : process { setsched } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2355930 + bz#2356058 + bz#2357154"
        rlSESearchRule "allow init_t pcscd_t : process2 { nnp_transition } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- bz#624405"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
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

