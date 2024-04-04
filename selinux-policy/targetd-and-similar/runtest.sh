#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/targetd-and-similar
#   Description: SELinux interferes with targetd and related programs
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
FILE_PATH="/usr/bin/targetd"
FILE_CONTEXT="targetd_exec_t"
SERVICE_PACKAGE="targetd"
SERVICE_NAME="targetd"
PROCESS_NAME="targetd"
PROCESS_CONTEXT="targetd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup --clean /etc/target/saveconfig.json
        rlFileBackup --clean /etc/target/targetd.yaml
        rlFileBackup /etc/lvm/lvm.conf
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1063714"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlSESearchRule "allow targetd_t lvm_control_t : chr_file { getattr open read write ioctl } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1373860 + bz#1486252"
        rlSEMatchPathCon "/usr/bin/targetd" "targetd_exec_t"
        rlSESearchRule "allow targetd_t targetd_t : unix_dgram_socket { create getopt setopt ioctl }"
        rlSESearchRule "allow targetd_t proc_net_t : file { getattr open read }"
        rlSESearchRule "dontaudit targetd_t targetd_t : capability { net_admin }"
        rlSESearchRule "allow targetd_t kernel_t : unix_dgram_socket { sendto }"
        rlSESearchRule "dontaudit targetd_t rpm_exec_t : file { getattr }"
        rlSESearchRule "allow targetd_t tmp_t : dir { getattr open read }"
        rlSESearchRule "dontaudit targetd_t rpm_var_lib_t : file { getattr open }"
        rlSESearchRule "dontaudit targetd_t semanage_store_t : dir { getattr }"
        rlSESearchRule "allow targetd_t bin_t : file { getattr open read execute_no_trans }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1424621 + bz#1486259"
        rlSEMatchPathCon "/var/run/dmeventd-client" "lvm_var_run_t"
        rlSESearchRule "allow targetd_t bin_t : file { getattr open read execute_no_trans }"
        rlSESearchRule "allow targetd_t targetd_t : tcp_socket { accept }"
        if rlIsRHEL 5 6 7 ; then
            rlSESearchRule "dontaudit targetd_t insmod_exec_t : file { getattr }"
        fi
        rlSESearchRule "allow targetd_t configfs_t : dir { add_name create getattr open read remove_name rmdir search write }"
        rlSESearchRule "allow targetd_t configfs_t : file { getattr open read write }"
        rlSESearchRule "allow targetd_t configfs_t : lnk_file { create getattr read unlink }"
        # following 2 rules seem to needed by btrfs tool
        # rlSESearchRule "allow targetd_t default_t : dir { ioctl read write }"
        # rlSESearchRule "allow targetd_t unlabeled_t : dir { ioctl read write }"
        # rlSESearchRule "allow targetd_t mnt_t : dir { ioctl read write }"
        rlSESearchRule "allow targetd_t exports_t : file { getattr open read }"
        rlSESearchRule "allow targetd_t fixed_disk_device_t : blk_file { write }"
        rlSESearchRule "allow targetd_t fs_t : filesystem { getattr }"
        rlSESearchRule "allow targetd_t kernel_t : system { ipc_info module_request }"
        if rlIsRHEL 7 ; then
           rlSESearchRule "allow targetd_t lvm_metadata_t : dir { add_name read remove_name write }"
           rlSESearchRule "allow targetd_t lvm_metadata_t : file { create link rename unlink append }"
           rlSESearchRule "allow targetd_t lvm_var_run_t : fifo_file { getattr open lock read write }"
        fi
        rlSESearchRule "allow targetd_t modules_conf_t : dir { getattr open read }"
        rlSESearchRule "allow targetd_t modules_conf_t : file { getattr open read }"
        rlSESearchRule "allow targetd_t modules_object_t : dir { search }"
        rlSESearchRule "allow targetd_t modules_object_t : file { getattr open read }"
        rlSESearchRule "allow targetd_t nfsd_fs_t : file { getattr open read }"
        rlSESearchRule "allow targetd_t targetd_t : capability { ipc_lock sys_admin sys_nice }"
        rlSESearchRule "allow targetd_t targetd_t : process { setsched }"
        rlSESearchRule "allow targetd_t sysctl_rpc_t : dir { search }"
        rlSESearchRule "allow targetd_t sysctl_rpc_t : file { getattr open read write }"
        rlSESearchRule "allow targetd_t sysfs_t : file { write }"
        rlSESearchRule "allow targetd_t var_lib_nfs_t : dir { add_name remove_name write }"
        rlSESearchRule "allow targetd_t var_lib_nfs_t : file { create getattr lock open read rename unlink write }"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1569663"
        rlSEMatchPathCon "/etc/lvm/lvm.conf" "lvm_etc_t"
        rlSESearchRule "allow targetd_t lvm_etc_t : file { map }"
    rlPhaseEnd

    rlPhaseStartTest "bz#2062183"
        rlSEMatchPathCon "/usr/sbin/lvm" "lvm_exec_t"
        rlSESearchRule "allow targetd_t lvm_exec_t : file { getattr open read execute map } [ ]"
        rlSESearchRule "type_transition targetd_t lvm_exec_t : process lvm_t"
        rlSESearchRule "allow targetd_t lvm_t : process { transition } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1546671"
        rlSEMatchPathCon "/usr/bin/targetd" "targetd_exec_t"
        rlSEMatchPathCon "/root/.local" "gconf_home_t"
        rlSEMatchPathCon "/home/user/.local" "gconf_home_t"
        rlSEMatchPathCon "/etc/lvm/lvm.conf" "lvm_etc_t"
        rlSESearchRule "allow targetd_t gconf_home_t : dir { search }"
        rlSESearchRule "allow targetd_t lvm_etc_t : file { map }"
    rlPhaseEnd

    rlPhaseStartTest "bz#2203720"
        rlSEMatchPathCon "/usr/bin/targetd" "targetd_exec_t"
        rlSEMatchPathCon "/etc/httpd" "httpd_config_t"
        rlSEMatchPathCon "/etc/httpd/conf" "httpd_config_t"
        rlSESearchRule "dontaudit targetd_t httpd_config_t : dir { search } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2222199"
        rlSEMatchPathCon "/usr/bin/targetd" "targetd_exec_t"
        if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] ; then
            rlRun "ls -dZ /proc/sys/net | grep :sysctl_net_t"
            rlRun "ls -dZ /proc/sys/net/ipv6 | grep :sysctl_net_t"
            rlRun "ls -dZ /proc/sys/net/ipv6/conf | grep :sysctl_net_t"
            rlRun "ls -dZ /proc/sys/net/ipv6/conf/all | grep :sysctl_net_t"
            rlRun "ls -Z /proc/sys/net/ipv6/conf/all/disable_ipv6 | grep :sysctl_net_t"
        fi
        rlSESearchRule "allow targetd_t sysctl_net_t : dir { search } [ ]"
        rlSESearchRule "allow targetd_t sysctl_net_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "rm -f /etc/target/saveconfig.json"
        rlRun "rm -f /etc/target/targetd.yaml"
        rlRun "targetctl clear"
        rlRun "targetctl save"
        rlRun "echo \"password: Str0nGp4ssw0rD\" > /etc/target/targetd.yaml"
        rlRun "sed -i \"s/use_lvmetad = 1/use_lvmetad = 0/\" /etc/lvm/lvm.conf"
        rlRun "ls -Z /etc/target"
        LOOP_FILE="vg-targetd.img"
        LOOP_DEVICE=`losetup -f`
        rlRun "dd if=/dev/zero of=${LOOP_FILE} bs=1MB count=128"
        rlRun "losetup ${LOOP_DEVICE} ${LOOP_FILE}"
        rlRun "vgcreate vg-targetd ${LOOP_DEVICE}"
        rlRun "vgdisplay"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for RHELs where the SELinux domain does not exist yet
            PROCESS_CONTEXT="initrc_t"
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "targetcli ls"
        rlRun "targetcli version"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
        rlRun "vgremove vg-targetd"
        rlRun "losetup -d ${LOOP_DEVICE}"
        rlRun "rm -f ${LOOP_FILE}"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

