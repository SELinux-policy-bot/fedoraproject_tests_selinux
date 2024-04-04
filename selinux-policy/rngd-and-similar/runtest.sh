#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/rngd-and-similar
#   Description: SELinux interferes with rngd and related programs
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
FILE_PATH="/sbin/rngd"
FILE_CONTEXT="rngd_exec_t"
SERVICE_PACKAGE="rng-tools"
SERVICE_NAME="rngd"
PROCESS_NAME="rngd"
PROCESS_CONTEXT="rngd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow
        rlFileBackup /etc/sysconfig/rngd

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } ${BOOLEANS}"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} ${BOOLEANS}"
    rlPhaseEnd

    rlPhaseStartTest "bz#869810 + bz#869813"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlRun "ls -Z /proc | grep :proc_t"
        rlRun "ls -Z /proc/sys | grep :sysctl_t"
        rlRun "ls -Z /proc/sys/kernel | grep :sysctl_kernel_t"
        rlRun "ls -Z /proc/sys/kernel/random | grep :sysctl_kernel_t"
        rlRun "ls -Z /proc/sys/kernel/random/poolsize | grep :sysctl_kernel_t"
        rlSESearchRule "allow rngd_t proc_t : dir { getattr open search }"
        rlSESearchRule "allow rngd_t sysctl_t : dir { getattr open search }"
        rlSESearchRule "allow rngd_t sysctl_kernel_t : dir { getattr open search }"
        rlSESearchRule "allow rngd_t sysctl_kernel_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1451735 + bz#1452629"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlSESearchRule "allow rngd_t sysfs_t : dir { getattr open search }"
        rlSESearchRule "allow rngd_t sysfs_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1496260"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlSEMatchPathCon "/dev/ttyUSB0" "usbtty_device_t"
        rlSESearchRule "allow rngd_t usbtty_device_t : chr_file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1609466 + bz#1611413 + bz#1612456"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlSEMatchPathCon "/etc/pki" "cert_t"
        rlSEMatchPathCon "/etc/pki/tls" "cert_t"
        rlSEMatchPathCon "/etc/pki/tls/legacy-settings" "cert_t"
        rlSESearchRule "allow rngd_t cert_t : dir { getattr open search }"
        rlSESearchRule "allow rngd_t cert_t : file { getattr open read }"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1653872 + bz#1655079 + bz#1657250 + bz#1658234"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlSESearchRule "allow rngd_t rngd_t : process { setsched } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1656054"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlRun "ls -Z /proc/cpuinfo | grep :proc_t"
        rlSESearchRule "allow rngd_t proc_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1698575 + bz#1699278 + bz#1700222"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlRun "ls -Z /proc/sys/kernel/random/write_wakeup_threshold | grep :sysctl_kernel_t"
        rlSESearchRule "allow rngd_t sysctl_kernel_t : file { write } [ ]"
    rlPhaseEnd
    fi

    if rlIsFedora ; then
    rlPhaseStartTest "bz#1787661 + bz#1787663 + bz#1789902"
        rlSEMatchPathCon "/usr/sbin/rngd" "rngd_exec_t"
        rlSEMatchPathCon "/var/lib/sss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/mc" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/mc/passwd" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/pipes" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSESearchRule "allow rngd_t passwd_file_t : file { getattr open read } [ ]"
        rlSESearchRule "allow rngd_t sssd_public_t : dir { search } [ ]"
        rlSESearchRule "allow rngd_t sssd_public_t : file { getattr open read map } [ ]"
        rlSESearchRule "allow rngd_t sssd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow rngd_t sssd_var_lib_t : dir { search } [ ]"
        rlSESearchRule "allow rngd_t sssd_var_lib_t : sock_file { getattr open write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1928572 + bz#1929360 + bz#1929366"
        rlSEMatchPathCon "/sys" "sysfs_t"
        rlSESearchRule "allow rngd_t sysfs_t : filesystem { getattr } [ ]"
    rlPhaseEnd
    fi

    DROP_PRIV=false
    if rngd --help | grep -qi 'drop.*priv' ; then
        DROP_PRIV=true
        rlPhaseStartTest "bz#2076641 + bz#2076642"
            rlSESearchRule "allow rngd_t rngd_t : capability { setgid setuid } [ ]"
            rlSESearchRule "allow rngd_t rngd_t : process { setcap } [ ]"
        rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlRun "modprobe tpm-rng" 0,1
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "setsebool daemons_use_tty on"
        rlRun "runcon system_u:system_r:initrc_t:s0 bash -c 'rngd -l'" 0-255
        rlRun "setsebool daemons_use_tty off"
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        if ${DROP_PRIV} ; then
            rlLog "modifying the /etc/sysconfig/rngd file"
            if ! grep -q '^RNGD_ARGS.*daemon:daemon' /etc/sysconfig/rngd ; then
                sed -i 's/^\(RNGD_ARGS=.*\)"$/\1 -D daemon:daemon"/' /etc/sysconfig/rngd
            fi
            if ! grep -q '^RNGD_ARGS.*jitter' /etc/sysconfig/rngd ; then
                sed -i 's/^\(RNGD_ARGS=.*\)"$/\1 -x jitter"/' /etc/sysconfig/rngd
            fi
        fi
        rlRun "grep ^RNGD_ARGS= /etc/sysconfig/rngd"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

