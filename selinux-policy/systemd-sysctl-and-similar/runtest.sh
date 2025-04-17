#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-sysctl-and-similar
#   Description: Does the systemd-sysctl work correctly under SELinux confinement?
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
PROCESS_CONTEXT="systemd_sysctl_t"
PROCESS_NAME="systemd-sysctl"
SERVICE_NAME="systemd-sysctl"
SERVICE_PACKAGE="systemd"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 8 && ! rlIsCentOS 8 ; then
        rlPhaseStartTest "bz#2056207 + bz#2056999"
            rlSEMatchPathCon "/usr/lib/systemd/systemd-sysctl" "systemd_sysctl_exec_t"
            rlRun "ls -Z /proc/sys/fs/suid_dumpable | grep :proc_security_t"
            rlRun "ls -Z /proc/sys/fs/protected_hardlinks | grep :proc_security_t"
            rlRun "ls -Z /proc/sys/fs/protected_symlinks | grep :proc_security_t"
            rlRun "ls -Z /proc/sys/kernel/kptr_restrict | grep :proc_security_t"
            rlSESearchRule "allow systemd_sysctl_t proc_security_t : file { read } [ ]"
        rlPhaseEnd

        if ! rlIsRHEL "<9.6" ; then
        rlPhaseStartTest "RHEL-56988 + RHEL-58380"
            rlRun "man sysctl.d | grep /run/sysctl"
            rlRun "mkdir -pZ /run/sysctl.d"
            rlRun "echo 'net.ipv4.conf.eno1.rp_filter=0' > /run/sysctl.d/51-rp_filter.conf"
            rlRun "restorecon -Rv /run/sysctl.d"
            rlRun "service systemd-sysctl stop"
            rlRun "service systemd-sysctl start"
            rlRun "service systemd-sysctl status" 0,3
        rlPhaseEnd
        fi
    fi

    rlPhaseStartTest "real scenario"
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} - ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

