#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/qat-service-and-similar
#   Description: SELinux interferes qatlib and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
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
#   License along with this program; if not, see
#   <https://www.gnu.org/licenses/>.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
FILE_PATH=`which qat_init.sh`
SERVICE_NAME="qat"
PROCESS_NAME="qat_init.sh"
if seinfo -t | grep -q qatlib ; then
    FILE_CONTEXT="qatlib_exec_t"
    PROCESS_CONTEXT="qatlib_t"
else
    FILE_CONTEXT="bin_t"
    PROCESS_CONTEXT="unconfined_service_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qf ${FILE_PATH}"

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined ${PROCESS_CONTEXT} ; then
    rlPhaseStartTest "BZ#2080443"
        rlRun "semodule -lfull | grep qatlib"
        rlSESearchRule "allow qatlib_t systemd_unit_file_t : dir { search } [ ]"
        rlSESearchRule "allow qatlib_t sssd_public_t : dir { search } [ ]"
        rlSESearchRule "allow qatlib_t sssd_var_lib_t : dir { search } [ ]"
        rlSESearchRule "allow qatlib_t sysfs_t : file { write } [ ]"
        rlSESearchRule "allow qatlib_t kmod_exec_t : file { getattr open read map execute execute_no_trans } [ ]"
        rlSESearchRule "allow qatlib_t modules_conf_t : dir { getattr open read } [ ]"
        rlSESearchRule "allow qatlib_t proc_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-19051 + RHEL-19052"
        rlSESearchRule "allow qatlib_t var_run_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition qatlib_t var_run_t : sock_file qatlib_var_run_t"
        rlSESearchRule "allow qatlib_t qatlib_var_run_t : sock_file { create } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-53864 + RHEL-66334"
        rlRun "semanage fcontext -l | grep '/sys/kernel/debug.*:debugfs_t:'"
        rlRun "semanage fcontext -l | grep '/dev/vfio/.*:vfio_device_t'"
        rlSESearchRule "allow qatlib_t debugfs_t : dir { getattr open search } [ ]"
        rlSESearchRule "allow qatlib_t vfio_device_t : chr_file { getattr read write ioctl } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-133797 + RHEL-133799"
        for CUR_FILE in `find /lib/modules -type f -name modules.dep.bin` ; do
            rlSEMatchPathCon $CUR_FILE "modules_dep_t"
        done
        rlSESearchRule "allow qatlib_t modules_dep_t : file { map } [ ]"
        rlSESearchRule "allow qatlib_t modules_object_t : file { map } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-211077"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSEMatchPathCon "/dev/hugepages" "hugetlbfs_t"
        rlSESearchRule "allow qatlib_t hugetlbfs_t : dir { getattr } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-211089 + RHEL-251355"
        rlRun "matchpathcon /dev/hugepages/qat | grep -i none"
        rlSESearchRule "allow qatlib_t hugetlbfs_t : dir { search create add_name write setattr } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "modprobe intel_qat"
        rlRun "lsmod | grep qat"
        rlRun "service ${SERVICE_NAME} start" 0,1
        rlRun "service ${SERVICE_NAME} status -l --no-pager" 0,1,3
        sleep 2
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlRun "service ${SERVICE_NAME} restart" 0,1
        rlRun "service ${SERVICE_NAME} status -l --no-pager" 0,1,3
        sleep 2
        rlRun "service ${SERVICE_NAME} stop" 0,1
        rlRun "service ${SERVICE_NAME} status -l --no-pager" 0,1,3
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

