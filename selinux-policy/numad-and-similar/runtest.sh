#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/numad-and-similar
#   Description: SELinux interferes with numad and related programs
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
SERVICE_NAME="numad"
PROCESS_NAME="numad"
PROCESS_CONTEXT="numad_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm numad

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined "numad_t numad_exec_t" ; then
    rlPhaseStartTest "bz#807157"
        rlSEMatchPathCon "/usr/bin/numad" "numad_exec_t"
        rlSESearchRule "allow initrc_t numad_t : process { transition }"
    rlPhaseEnd
    fi

    if rlSEDefined "numad_exec_t cgroup_t numad_t" ; then
    rlPhaseStartTest "bz#857086"
        rlSEMatchPathCon "/usr/bin/numad" "numad_exec_t"
        if rlIsRHEL 6 ; then
            MOUNT_POINT="/cgroup/cpuset"
            rlSEMatchPathCon "${MOUNT_POINT}" "cgroup_t"
        else
            MOUNT_POINT="/sys/fs/cgroup/cpuset"
            if [ -d ${MOUNT_POINT} ] ; then
                rlRun "ls -dZ ${MOUNT_POINT} | grep :cgroup_t"
            else
                rlSEMatchPathCon "/sys/fs/cgroup" "cgroup_t"
            fi
        fi
        rlSESearchRule "allow numad_t cgroup_t : dir { getattr search }"
        rlSESearchRule "allow numad_t numad_t : msg { send receive }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1074449"
        rlSEMatchPathCon "/usr/bin/numad" "numad_exec_t"
        rlSESearchRule "allow numad_t sysfs_t : file { write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1118515"
        rlSEMatchPathCon "/usr/bin/numad" "numad_exec_t"
        rlSEMatchPathCon "/var/log/numad.log" "numad_var_log_t"
        rlSEMatchPathCon "/var/run/numad.pid" "numad_var_run_t"
        rlSESearchRule "allow virtd_t numad_exec_t : file { getattr open read execute }"
        rlSESearchRule "type_transition virtd_t numad_exec_t : process numad_t"
        rlSESearchRule "allow virtd_t numad_t : process { transition }"
        rlSESearchRule "allow numad_t numad_var_log_t : file { open }"
        rlSESearchRule "allow numad_t numad_t : msg { send receive }"
        rlSESearchRule "allow numad_t numad_t : msgq { associate unix_read unix_write read write }"
        rlSESearchRule "allow numad_t numad_var_run_t : file { getattr open read }"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "mkdir -p ${MOUNT_POINT}"
        if ! mount | grep -q "cgroup.*cpuset" ; then
            rlRun "mount cgroup -t cgroup -o cpuset ${MOUNT_POINT}" 0,32
        fi
        rlRun "semodule -l | grep numad"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "numad -S 0"
        rlRun "numad -S 1"
        rlRun "restorecon -Rv /run /var"
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

