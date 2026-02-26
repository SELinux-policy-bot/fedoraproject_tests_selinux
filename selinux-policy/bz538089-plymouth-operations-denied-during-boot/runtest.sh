#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bz538089-plymouth-operations-denied-during-boot
#   Description: some plymouth operations are denied during boot because of SELinux
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2009 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/sbin/plymouthd"
FILE_CONTEXT="plymouthd_exec_t"
SERVICE_PACKAGE="plymouth"
SERVICE_NAME="plymouth-start"
PROCESS_NAME="plymouthd"
PROCESS_CONTEXT="plymouthd_t"

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

    rlPhaseStartTest "bz#538089"
        rlSEMatchPathCon "/bin/plymouth" "plymouth_exec_t"
        rlSEMatchPathCon "/sbin/cryptsetup" "lvm_exec_t"
        rlSEMatchPathCon "/dev/mapper/control" "lvm_control_t"
        rlRun "ls -Z /proc/devices | grep :proc_t"
        rlSESearchRule "allow plymouth_t lvm_exec_t : file { getattr open read execute }"
        rlSESearchRule "type_transition plymouth_t lvm_exec_t : process lvm_t"
        rlSESearchRule "allow plymouth_t lvm_t : process { transition }"
        rlSESearchRule "allow lvm_t lvm_t : capability { ipc_lock }"
        rlSESearchRule "allow lvm_t proc_t : file { getattr open read }"
        rlSESearchRule "allow lvm_t lvm_control_t : chr_file { getattr open read write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#560611"
        rlSEMatchPathCon "/bin/plymouth" "plymouth_exec_t"
        rlRun "ls -Z /proc/cmdline | grep :proc_t"
        rlSESearchRule "allow plymouth_t proc_t : file { getattr open read }"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#904016"
        rlSEMatchPathCon "/usr/sbin/plymouthd" "plymouthd_exec_t"
        rlSEMatchPathCon "/var/log/boot.log" "plymouthd_var_log_t"
        # when plymouthd runs as plymouthd_t
        rlSESearchRule "allow plymouthd_t var_log_t : dir { write add_name }"
        rlSESearchRule "type_transition plymouthd_t var_log_t : file plymouthd_var_log_t"
        rlSESearchRule "allow plymouthd_t plymouthd_var_log_t : file { create }"
        # when plymouthd runs as kernel_t
        rlSESearchRule "allow kernel_t var_log_t : dir { write add_name }"
        rlRun "sesearch -s kernel_t -t var_log_t -c file -T | grep 'plymouthd_var_log_t.*boot.log'"
        rlSESearchRule "allow kernel_t plymouthd_var_log_t : file { create }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1045382"
        rlSEMatchPathCon "/usr/sbin/plymouthd" "plymouthd_exec_t"
        rlSEMatchPathCon "/var/run/udev" "udev_var_run_t"
        rlSEMatchPathCon "/var/run/udev/queue.bin" "udev_var_run_t"
        rlSESearchRule "allow plymouthd_t plymouthd_t : netlink_kobject_uevent_socket { create setopt bind getattr }"
        rlSESearchRule "allow plymouthd_t udev_var_run_t : dir { search }"
        rlSESearchRule "allow plymouthd_t udev_var_run_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1160196"
        rlSEMatchPathCon "/usr/sbin/plymouthd" "plymouthd_exec_t"
        rlSEMatchPathCon "/var/lib/sss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/mc" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/mc/group" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/pipes" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSESearchRule "allow plymouthd_t sssd_public_t : dir { getattr search open }"
        rlSESearchRule "allow plymouthd_t sssd_public_t : file { getattr open read }"
        rlSESearchRule "allow plymouthd_t sssd_var_lib_t : dir { getattr search open }"
        rlSESearchRule "allow plymouthd_t sssd_var_lib_t : sock_file { write getattr append open }"
    rlPhaseEnd
    fi

    if rlIsRHEL 6 ; then
    rlPhaseStartTest "bz#1131195"
        rlSEMatchPathCon "/var/spool/plymouth/boot.log" "plymouthd_spool_t"
        rlSESearchRule "allow xdm_t plymouthd_spool_t : file { getattr }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1202429"
        rlSEMatchPathCon "/dev/ttyUSB0" "usbtty_device_t"
        rlSESearchRule "allow plymouthd_t usbtty_device_t : chr_file { read write } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1517405"
        rlSEMatchPathCon "/dev/fb0" "framebuf_device_t"
        rlSESearchRule "allow plymouthd_t framebuf_device_t : chr_file { map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1664143"
        rlSEMatchPathCon "/sys/firmware/efi/efivars" "efivarfs_t"
        rlSESearchRule "allow plymouthd_t efivarfs_t : dir { getattr open search } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1869814 + bz#1871307"
        rlSESearchRule "allow plymouthd_t plymouthd_t : capability { sys_chroot } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL "<9.3" ; then
    rlPhaseStartTest "bz#2184803"
        rlSESearchRule "allow plymouthd_t plymouthd_t : capability2 { bpf } [ ]"
    rlPhaseEnd
    fi

    if rlIsFedora ; then
    rlPhaseStartTest "bz#2256442"
        rlSEMatchPathCon "/dev/kmsg" "kmsg_device_t"
        rlSESearchRule "allow plymouthd_t kmsg_device_t : chr_file { open read write } [ ]"
        rlSESearchRule "allow plymouthd_t kernel_t : system { syslog_read } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for environments where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
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

