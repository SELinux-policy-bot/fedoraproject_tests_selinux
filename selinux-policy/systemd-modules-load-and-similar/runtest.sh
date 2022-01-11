#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-modules-load-and-similar
#   Description: SELinux interferes with the systemd-modules-load service and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/lib/systemd/systemd-modules-load"
FILE_CONTEXT="systemd_modules_load_exec_t"
SERVICE_PACKAGE="systemd-udev"
SERVICE_NAME="systemd-modules-load"
PROCESS_NAME="systemd-modules-load"
PROCESS_CONTEXT="systemd_modules_load_t"
KERNEL_MODULE="nf_conntrack_pptp"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
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
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#1358526 + bz#1358960 + bz#1360157"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-modules-load" "systemd_modules_load_exec_t"
        rlSEMatchPathCon "/etc/modprobe.d" "modules_conf_t"
        rlSEMatchPathCon "/etc/modprobe.d/something.conf" "modules_conf_t"
        rlSESearchRule "allow systemd_modules_load_t modules_conf_t : dir { getattr open search } [ ]"
        rlSESearchRule "allow systemd_modules_load_t modules_conf_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1360488 + bz#1490015"
        rlSEMatchPathCon "/usr/lib/modules/some-kernel/extra/some-module.ko" "modules_object_t"
        rlSESearchRule "allow systemd_modules_load_t modules_object_t : file { getattr open read map } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1493293 + bz#1697632 + bz#1698200 + bz#1699559"
        rlSEMatchPathCon "/usr/lib/modules/some-kernel/modules.alias.bin" "modules_dep_t"
        rlSEMatchPathCon "/usr/lib/modules/some-kernel/modules.dep.bin" "modules_dep_t"
        rlSEMatchPathCon "/usr/lib/modules/some-kernel/modules.softdep" "modules_dep_t"
        rlSESearchRule "allow systemd_modules_load_t modules_dep_t : file { getattr open read map } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1437153 + bz#1438253"
        rlSESearchRule "allow systemd_modules_load_t systemd_modules_load_t : system { module_load } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1823246"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-modules-load" "systemd_modules_load_exec_t"
        rlSEMatchPathCon "/usr/bin/bash" "shell_exec_t"
        rlSEMatchPathCon "/usr/bin/kmod" "kmod_exec_t"
        rlSEMatchPathCon "/usr/sbin/sysctl" "bin_t"
        rlSESearchRule "allow systemd_modules_load_t shell_exec_t : file { execute execute_no_trans map } [ ]"
        rlSESearchRule "allow systemd_modules_load_t kmod_exec_t : file { getattr open read execute execute_no_trans } [ ]"
        rlSESearchRule "allow systemd_modules_load_t bin_t : file { execute execute_no_trans map } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1819161 + bz#1824196 + bz#1829700 + bz#1833502 + bz#1838933 + bz#1972372"
        rlSEMatchPathCon "/sys/firmware/efi/efivarfs" "efivarfs_t"
        rlSESearchRule "allow systemd_modules_load_t efivarfs_t : file { getattr open read } [ ]"
        rlSESearchRule "allow systemd_resolved_t efivarfs_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlRun "echo ${KERNEL_MODULE} > /etc/modules-load.d/${KERNEL_MODULE}.conf"
        rlRun "lsmod"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "lsmod | grep ${KERNEL_MODULE}"
        rlRun "restorecon -Rv /run /var" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} - ${PROCESS_CONTEXT} "stop status" 1
        rlRun "lsmod"
        rlRun "rm -f /etc/modules-load.d/${KERNEL_MODULE}.conf"
    rlPhaseEnd

    rlPhaseStartTest "bz#1942267"
        tst_Time="$(date '+%T')"
        # Install kernel-module matching the running kernel version
        rlRun "dnf -y install kernel-modules-$(uname -r)"
        rlRun "systemctl start rdma-load-modules@rdma.service"
        rlRun "systemctl status rdma-load-modules@rdma.service"
        rlRun "lsmod | grep rdma"
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time" 1
        rlRun "systemctl stop rdma-load-modules@rdma.service"
        if ! rlIsRHEL 8 ; then
            rlSESearchRule "allow systemd_modules_load_t systemd_modules_load_t : lockdown { confidentiality } [ ]"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

