#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bz533007-unable-to-start-kdump-service
#   Description: kdump service cannot be started because of SELinux
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

if ! grep crashkernel= /proc/cmdline ; then
    grubby --update-kernel ALL --args crashkernel=512M
    sync
    rhts-reboot
fi

PACKAGE="selinux-policy"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-mls
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm kexec-tools
        rlRun "uname -a"
        rlRun "cat /proc/cmdline"

        rlFileBackup --clean /root/.ssh
        rlFileBackup /etc/kdump.conf
        rlFileBackup /etc/shadow
        OUTPUT_FILE=`mktemp`

        if rlIsRHEL 6 ; then
            rlRun "ls -l testpolicy.te"
            rlRun "make -f /usr/share/selinux/devel/Makefile"
            rlRun "ls -l testpolicy.pp"
            rlRun "semodule -i testpolicy.pp"
        fi

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#533007 + bz#533366 + bz#540758 + bz#549503 + bz#966203"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlRun "ls -Z /proc/kcore | grep :proc_kcore_t"
        if rlIsRHEL 6 ; then
            rlRun "seinfo -tkdump_t -x | grep mlsfileread"
        fi
        rlSESearchRule "allow kdump_t proc_kcore_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#537088"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlSESearchRule "allow kdump_t kdump_t : capability { sys_rawio }"
    rlPhaseEnd

    rlPhaseStartTest "bz#618329"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        [ -e /sys/kernel/debug/boot_params/data ] && rlRun "ls -Z /sys/kernel/debug/boot_params/data | grep :debugfs_t"
        rlSESearchRule "allow kdump_t user_devpts_t : chr_file { read write } [ allow_daemons_use_tty ]"
        rlSESearchRule "allow kdump_t sysfs_t : dir { getattr read search }"
        rlSESearchRule "allow kdump_t sysfs_t : file { getattr open read }"
        rlSESearchRule "allow kdump_t debugfs_t : dir { getattr search }"
        rlSESearchRule "allow kdump_t debugfs_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#621061"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlSESearchRule "allow kdump_t kernel_t : system { module_request }"
    rlPhaseEnd
    fi

    if rlIsRHEL 6 ; then
    rlPhaseStartTest "bz#1288565 + bz#1431236"
        rlSEMatchPathCon "/usr/sbin/bmc-watchdog" "freeipmi_bmc_watchdog_exec_t"
        rlSEMatchPathCon "/var/lock/kdump" "kdump_lock_t"
        # even though the context of /var/lock/kdump was corrected via restorecon before reboot
        # after reboot the file was mislabeled (var_lock_t) again
        rlSESearchRule "dontaudit freeipmi_bmc_watchdog_t var_lock_t : file { write }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1055634" # MLS + targeted
        rlSEMatchPathCon "/usr/bin/kdumpctl" "kdumpctl_exec_t"
        rlSEMatchPathCon "/var/lock" "var_lock_t"
        rlSEMatchPathCon "/var/lock/kdump" "kdump_lock_t"
        rlSESearchRule "allow kdumpctl_t var_lock_t : lnk_file { getattr read }"
        rlSESearchRule "allow kdumpctl_t var_lock_t : dir { getattr open search read write add_name remove_name }"
        rlRun "sesearch -s kdumpctl_t -t var_lock_t -c file -T | grep \"kdump_lock_t.*kdump\""
        rlSESearchRule "allow kdumpctl_t kdump_lock_t : file { getattr open create unlink }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1117368 + bz#1117710 + bz#1146491"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlRun "ls -Z /proc/kallsyms | grep :system_map_t"
        rlSESearchRule "allow kdump_t system_map_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1363977"
        rlSESearchRule "allow NetworkManager_t kdumpctl_t : dbus { send_msg }"
        rlSESearchRule "allow kdumpctl_t NetworkManager_t : dbus { send_msg }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1375963 + bz#1418441"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlSESearchRule "allow kdump_t kdump_t : capability { sys_admin }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1390669"
        rlSEMatchPathCon "/usr/bin/kdumpctl" "kdumpctl_exec_t"
        if [ -f /sys/kernel/security/securelevel ] ; then
            # the file is present on RHEL-7.5: kernel 3.10
            # the file is not present on RHEL-ALT-7.5: kernel 4.14
            rlRun "ls -Z /sys/kernel/security/securelevel | grep :security_t"
        fi
        rlSESearchRule "allow kdumpctl_t security_t : file { getattr open read } mls"
        rlSESearchRule "allow kdumpctl_t security_t : file { getattr open read } targeted"
    rlPhaseEnd

    rlPhaseStartTest "bz#1540004 + bz#1542283"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlSESearchRule "allow kdump_t kdump_t : capability2 { syslog }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1536690"
        rlSESearchRule "allow kdump_t modules_object_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1576730 + bz#1588884"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlSEMatchPathCon "/boot/initramfs-4.16.0-8.el8+5.s390xkdump.img" "boot_t"
        rlSESearchRule "allow kdump_t boot_t : file { map }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1842897"
        # relevant SELinux denials appear during the real scenario phases
        rlSESearchRule "dontaudit NetworkManager_t kdumpctl_tmp_t : fifo_file { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1896424 + bz#1896595 + bz#1899141"
        rlSEMatchPathCon "/sbin/kexec" "kdump_exec_t"
        rlSESearchRule "allow kdump_t tmp_t : dir { write add_name remove_name } [ ]"
        rlSESearchRule "allow kdump_t tmp_t : file { create unlink } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1951323 + bz#1961728 + bz#1965985 + bz#1965989"
        # the directory belongs to the kexec-tools package
        rlSEMatchPathCon "/var/lib/kdump" "kdump_var_lib_t"
        rlSEMatchPathCon "/var/lib/kdump/initramfs-kernel-version.kdump.img" "kdump_var_lib_t"
        rlSESearchRule "allow kdump_t kdump_var_lib_t : dir { getattr open search add_name remove_name read write } [ ]"
        rlSESearchRule "allow kdump_t kdump_var_lib_t : file { getattr open read } [ ]"
        rlSESearchRule "allow rpm_script_t kdump_var_lib_t : dir { getattr open search add_name remove_name read write } [ ]"
        rlSESearchRule "allow rpm_script_t kdump_var_lib_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if rlIsFedora ; then
    rlPhaseStartTest "bz#2236876"
        rlSESearchRule "allow kdump_t tmpfs_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition kdump_t tmpfs_t : file kdump_tmpfs_t"
        rlSESearchRule "allow kdump_t kdump_tmpfs_t : file { read write } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "sed -i \"s/^\(net.*\)$/# \1/\" /etc/kdump.conf"
        rlRun "service kdump start 2>&1 | tee ${OUTPUT_FILE}"
        rlRun "grep -i \"unable to gather efi data\" ${OUTPUT_FILE}" 1
        sleep 1
        rlRun "service kdump restart 2>&1 | tee ${OUTPUT_FILE}"
        rlRun "grep -i \"unable to gather efi data\" ${OUTPUT_FILE}" 1
        sleep 1
        rlRun "service kdump stop"
        sleep 1
        rlRun "grep \"kdump.*kexec.*loaded.*kernel\" /var/log/messages | tail -n 2"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#753039"
        USER_NAME="root"
        USER_SECRET="redhat"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "mkdir -p /root/.ssh"
        rlRun "restorecon -Rv /root/.ssh"
        rlRun "cp id_rsa /root/.ssh/"
        rlRun "chmod 600 /root/.ssh/id_rsa"
        rlRun "cat id_rsa.pub >> /root/.ssh/authorized_keys"

        if rlIsRHEL 5 6 ; then
            rlRun "echo \"net ${USER_NAME}@${HOSTNAME}\" >> /etc/kdump.conf"
            rlRun "./run.exp ${USER_SECRET} service kdump propagate"
        else
            rlRun "sed -i \"s/makedumpfile/makedumpfile -F/\" /etc/kdump.conf"
            rlRun "echo \"ssh ${USER_NAME}@${HOSTNAME}\" >> /etc/kdump.conf"
            rlRun "./run.exp ${USER_SECRET} kdumpctl propagate"
            rlRun "runcon system_u:system_r:initrc_t:s0 bash -c \"kdumpctl showmem\""
        fi
        rlRun "service kdump restart"
        sleep 1
        rlRun "grep \"kdump.*propagated ssh key\" /var/log/messages | tail -n 1"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        if rlIsRHEL 6 ; then
            rlRun "semodule -r testpolicy"
            rlRun "rm -f testpolicy.pp"
        fi

        rm -f ${OUTPUT_FILE}
        rlFileRestore
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

