#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Sanity/systemd-oomd
#   Description: Testing systemd-oomd service
#   Author: Zdenek Pytela <zpytela@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
SERVICE_PACKAGE="systemd-oomd"
SERVICE_NAME="systemd-oomd"
FILE_PATH="/usr/lib/systemd/systemd-oomd"
FILE_CONTEXT="systemd_oomd_exec_t"
PROCESS_NAME="systemd-oomd"
PROCESS_CONTEXT="systemd_oomd_t"

### systemd-oomd is a system service that uses cgroups-v2 and pressure stall
### information (PSI) to monitor and take a corrective action before an OOM occurs
### in the kernel space.
### Monitoring and actions on units can be enabled by setting ManagedOOMSwap=
### and ManagedOOMMemoryPressure=. Cgroups of units with ManagedOOMSwap= or
### ManagedOOMMemoryPressure= set to kill will be monitored.

rlJournalStart
    if [ ! -x ${FILE_PATH} ]; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlSEConfigureSSH
        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        rlRun "cat /etc/system-release"
        rlRun "uname -a"
        rlRun "rpm -qa | grep -e selinux-policy -e systemd | sort"
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        # Is the service SELinux confined?
        CONTEXT=$(stat -c"%C" "${FILE_PATH}")
        if [[ ${CONTEXT} =~ ":init_exec_t:" ]] ; then
            rlLog "The ${SERVICE_NAME} service is not SELinux confined."
        else
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow systemd_oomd_t proc_psi_t : file { getattr ioctl lock open read } [ ]"
        rlSESearchRule "allow systemd_oomd_t domain : dir { getattr ioctl lock open read search } [ ]"
        rlSESearchRule "allow systemd_oomd_t domain : file { getattr ioctl lock open read } [ ]"
        rlSESearchRule "allow systemd_oomd_t cgroup_t : dir { getattr ioctl lock open read search setattr write } [ ]"
        rlSESearchRule "allow systemd_oomd_t domain : process { sigkill } [ ]"
        rlSESearchRule "allow systemd_oomd_t self : capability { kill } [ ]"
        fi
    rlPhaseEnd

    ### Basic systemd-oomd setup
    ### https://fedoraproject.org/wiki/Changes/EnableSystemdOomd#How_to_test
    rlPhaseStartTest "Real scenario"

        # sd-oomd conflicts earlyoom
        if systemctl list-unit-files earlyoom.service &>/dev/null; then
            rlRun "systemctl disable --now --quiet earlyoom.service"
        fi
        rlRun "systemctl enable --now ${SERVICE_NAME}"
        rlRun "systemctl status ${SERVICE_NAME}"

        # enable swap-based killing on all units in the root slice
        mkdir -p /etc/systemd/system/-.slice.d
        cat >> /etc/systemd/system/-.slice.d/override.conf << EOF
[Slice]
ManagedOOMSwap=kill
EOF

        # memory pressure example settings
        mkdir -p /etc/systemd/system/user@.service.d
        cat >> /etc/systemd/system/user@.service.d/override.conf << EOF
[Service]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=10%
EOF

        rlRun "systemctl daemon-reload"
        rlRun "systemctl restart ${SERVICE_NAME}"
        rlRun "systemctl status ${SERVICE_NAME}"

        # create a user and run a stress test - it can hang the system for a while
        USER_NAME="user${RANDOM}"
        USER_SECRET="S3kr3T${RANDOM}"
        rlRun "useradd -G systemd-journal ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"

        USER_ID=$(id -u ${USER_NAME})
        SYSTEM_SERVICE_NAME="user@${USER_ID}.service"
        USER_SERVICE_NAME="useroomcheck-${RANDOM}.service"
        rlRun "./ssh-sleep40.exp ${USER_NAME} ${USER_SECRET} localhost systemd-run --user -u ${USER_SERVICE_NAME} tail /dev/zero"

        rlLog "Checking journal for the oom killer string"
        rlRun "./ssh-nosleep.exp ${USER_NAME} ${USER_SECRET} localhost journalctl -u ${USER_SERVICE_NAME} -g \"A process of this unit has been killed by the OOM killer\""
        rlRun "./ssh-nosleep.exp ${USER_NAME} ${USER_SECRET} localhost journalctl --user -u ${USER_SERVICE_NAME} -g \"A process of this unit has been killed by the OOM killer\""

        rlRun "systemctl status ${SERVICE_NAME}"
        if [ "${DEBUG}" = "yes" ]; then
            rlLog "Displaying list of monitored cgroups and pressure information"
            rlRun "oomctl dump"
            rlLog "Displaying journal content for the system ${SYSTEM_SERVICE_NAME} service"
            rlRun "journalctl -u ${SYSTEM_SERVICE_NAME}"
            rlLog "Displaying journal content for the user ${USER_SERVICE_NAME} service"
            rlRun "./ssh-nosleep.exp ${USER_NAME} ${USER_SECRET} localhost journalctl --user -u ${USER_SERVICE_NAME}"
        fi
    rlPhaseEnd

    ### cleanup, restoring the previous content
    rlPhaseStartCleanup
        rlRun "userdel -rf ${USER_NAME}"
        rm -f /etc/systemd/system/-.slice.d/override.conf
        rm -f /etc/systemd/system/user@.service.d/override.conf
        rlRun "systemctl daemon-reload"
        rlSECheckAVC
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

