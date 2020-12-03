#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/swap-file-and-systemd-access
#   Description: SELinux interferes with systemd when accessing a swap file
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
REAL_SCENARIOS=${REAL_SCENARIOS:-true}

rlJournalStart
    if ! seinfo -t | grep -q systemd_sleep ; then
        rlDie "Not applicable to this SELinux policy version."
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm systemd
        rlAssertRpm util-linux
        rlRun "strings /usr/sbin/mkswap | grep swapfile_t"

        rlFileBackup /swapfile

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1367279"
        rlSEMatchPathCon "/usr/lib/systemd/systemd" "init_exec_t"
        rlSESearchRule "allow init_t swapfile_t : file { getattr } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1797543 + bz#1798872 + bz#1850177"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-sleep" "systemd_sleep_exec_t"
        rlSEMatchPathCon "/sys/power" "sysfs_t"
        rlSEMatchPathCon "/sys/power/state" "sysfs_t"
        rlSESearchRule "allow systemd_sleep_t swapfile_t : file { append getattr ioctl lock open read write } [ ]"
        rlSESearchRule "dontaudit systemd_sleep_t systemd_sleep_t : capability { sys_ptrace } [ ]"
        rlSESearchRule "allow systemd_sleep_t sysfs_t : dir { write } [ ]"
        rlSESearchRule "allow systemd_sleep_t sysfs_t : file { getattr open write } [ ]"
        rlSESearchRule "allow systemd_sleep_t systemd_sleep_t : capability { sys_resource } [ ]"
        rlSESearchRule "allow systemd_sleep_t kmsg_device_t : chr_file { write } [ ]"
        rlSESearchRule "allow systemd_sleep_t kernel_t : unix_dgram_socket { sendto } [ ]"
    rlPhaseEnd

    if rlIsFedora ; then
    rlPhaseStartTest "bz#1845594"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-logind" "systemd_logind_exec_t"
        rlSESearchRule "allow systemd_logind_t swapfile_t : file { getattr open read ioctl } [ ]"
    rlPhaseEnd
    fi

    if ${REAL_SCENARIOS} ; then
    rlPhaseStartTest "real scenario"
        rlRun "rm -f /swapfile"
        rlRun "dd if=/dev/zero of=/swapfile bs=1M count=256"
        rlRun "ls -Z /swapfile"
        rlRun "mkswap /swapfile"
        rlRun "ls -Z /swapfile | grep :swapfile_t"
        rlRun "free"
        rlRun "swapon /swapfile"
        rlRun "free"
        # TODO: 4 different services call systemd-sleep, any of them can be used
        for SERVICE_NAME in systemd-hybrid-sleep systemd-hibernate ; do
            rlRun "mkdir -p /etc/systemd/system/${SERVICE_NAME}.service.d"
            rlRun "echo -en '[Service]\nPrivateDevices=yes\n' > /etc/systemd/system/${SERVICE_NAME}.service.d/PrivateDevices.conf"
        done
        rlRun "systemctl daemon-reload"
        rlRun "systemctl start systemd-hybrid-sleep.service" 0,1
        rlRun "systemctl status systemd-hybrid-sleep.service" 0,3
        sleep 5
        rlRun "systemctl hibernate" 0,1
        sleep 5
        rlRun "swapoff /swapfile"
        rlRun "free"
        rlRun "rm -f /swapfile"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlFileRestore
        for SERVICE_NAME in systemd-hybrid-sleep systemd-hibernate ; do
            rlRun "rm -f /etc/systemd/system/${SERVICE_NAME}.service.d/PrivateDevices.conf"
        done
        rlRun "systemctl daemon-reload"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

