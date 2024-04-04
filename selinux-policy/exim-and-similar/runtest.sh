#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/exim-and-similar
#   Description: SELinux interferes with exim and related programs
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
FILE_PATH="/usr/sbin/exim"
FILE_CONTEXT="exim_exec_t"
SERVICE_PACKAGE="exim"
SERVICE_NAME="exim"
PROCESS_NAME="exim"
PROCESS_CONTEXT="exim_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow
        rlFileBackup /etc/exim/exim.conf

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#1025315"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
            rlSEMatchPathCon "/sys/devices/system/cpu" "sysfs_t"
            rlSEMatchPathCon "/sys/devices/system/cpu/online" "sysfs_t"
            rlSESearchRule "allow exim_t sysfs_t : file { getattr open read }"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
            rlSEMatchPathCon "/sys/devices/system/cpu" "sysfs_t"
            rlSEMatchPathCon "/sys/devices/system/cpu/online" "cpu_online_t"
            rlSESearchRule "allow exim_t cpu_online_t : file { getattr open read }"
        fi
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlSESearchRule "allow exim_t sysfs_t : dir { search }"
    rlPhaseEnd
    fi

    if rlIsRHEL 7 ; then
    rlPhaseStartTest "bz#1444441"
        rlSEMatchPathCon "/usr/sbin/exim" "exim_exec_t"
        rlSESearchRule "allow exim_t sysctl_net_t : dir { getattr open search } [ ]"
        rlSESearchRule "allow exim_t sysctl_net_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if rlIsRHEL 8 9 || rlIsCentOS 8 9 ; then
    rlPhaseStartTest "RHEL-21902 + RHEL-21903"
        rlSEMatchPathCon "/var/spool/exim/exim_daemon_notify" "exim_spool_t"
        rlSESearchRule "allow exim_t exim_t : unix_dgram_socket { sendto } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for RHELs where the SELinux domain does not exist yet
            PROCESS_CONTEXT="sendmail_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "lsof | grep exim_daemon_notify"
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- RHEL-14110 + RHEL-14186"
        rlSEMatchPathCon "/var/spool/exim/input" "exim_spool_t"
        rlSESearchRule "allow system_mail_t exim_spool_t : dir { create } [ ]"
        rlRun "sed -i 's/^.*\(split_spool_directory\).*=.*$/\1 = true/' /etc/exim/exim.conf"
        rlRun "service exim start"
        rlRun "service atd start"
        rlRun "echo '/usr/bin/id -Z' | at now"
        sleep 15s
        rlRun "ls -lZ /var/spool/exim/input"
        rlRun "service atd stop"
        rlRun "service exim stop"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

