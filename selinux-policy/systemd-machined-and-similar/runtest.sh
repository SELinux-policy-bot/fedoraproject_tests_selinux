#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-machined-and-similar
#   Description: SELinux interferes with systemd-machined and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/lib/systemd/systemd-machined"
FILE_CONTEXT="systemd_machined_exec_t"
SERVICE_PACKAGE="systemd-container"
SERVICE_NAME="systemd-machined"
PROCESS_NAME="systemd-machined"
PROCESS_CONTEXT="systemd_machined_t"
INSTALL_OPTION=""
if yum --help | grep -q use-host-config ; then
    INSTALL_OPTION="${INSTALL_OPTION} --use-host-config"
fi
if yum install --help | grep -q skip-broken ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-broken"
fi
if yum install --help | grep -q skip-unavailable ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-unavailable"
fi

rlJournalStart
    if [ ! -f ${FILE_PATH} ] ; then
        rlLog "The required program is not installed. Quitting..."
        rlJournalEnd
        exit 0
    fi

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

    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    if rlIsFedora ; then
    rlPhaseStartTest "bz#1847545"
        rlSESearchRule "allow systemd_machined_t unconfined_service_t : dir { search } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1900869 + bz#1900888"
        rlSESearchRule "allow system_dbusd_t devpts_t : chr_file { read write } [ ]"
        rlSESearchRule "allow systemd_machined_t devpts_t : chr_file { open read write ioctl } [ ]"
        rlSESearchRule "allow systemd_machined_t systemd_machined_t : cap_userns { sys_ptrace sys_admin setgid setuid } [ ]"
        rlSESearchRule "allow systemd_machined_t tmpfs_t : lnk_file { getattr read } [ ]"
        rlSESearchRule "allow systemd_machined_t tmpfs_t : sock_file { write } [ ]"
        rlSESearchRule "allow systemd_machined_t unconfined_service_t : dir { search } [ ]"
        rlSESearchRule "allow systemd_machined_t unconfined_service_t : file { getattr open read ioctl } [ ]"
        rlSESearchRule "allow systemd_machined_t unconfined_service_t : lnk_file { getattr read } [ ]"
        rlSESearchRule "allow systemd_machined_t unconfined_service_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "RHEL-49567"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-machined" "systemd_machined_exec_t"
        rlSEMatchPathCon "/run/systemd/machine" "systemd_machined_var_run_t"
        rlSEMatchPathCon "/run/systemd/machine/io.systemd.Machine" "systemd_machined_var_run_t"
        rlSESearchRule "allow systemd_machined_t systemd_machined_var_run_t : dir { create } [ ]"
        rlSESearchRule "allow systemd_machined_t systemd_machined_var_run_t : sock_file { create unlink } [ ]"
        rlRun "machinectl"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#1900869 + bz#1900888"
        rlRun "mkdir -pZ /var/lib/machines/test"
        rlRun "dnf -y --installroot=/var/lib/machines/test/ install dhcp-client dnf filesystem glibc glibc-langpack-en glibc-langpack-de iproute iputils less passwd systemd vim-minimal ${INSTALL_OPTION}"
        rlRun "du -sh /var/lib/machines/test"
        # TODO: remove next 2 lines once the BZs are fixed
        rlRun "semodule -i testpolicy.cil"
        rlRun "semodule -lfull | grep testpolicy"
        rlRun "systemctl start systemd-nspawn@test"
        rlRun "systemctl status systemd-nspawn@test"
        rlRun "ps -efZ | grep -e ${PROCESS_CONTEXT} -e unconfined_service_t"
        rlRun "machinectl list"
        rlRun "machinectl status test"
        rlWatchdog "machinectl login test" 20
        rlRun "rm -f /tmp/id"
        rlRun "machinectl copy-to test /usr/bin/id /tmp/id"
        rlRun "machinectl copy-from test /usr/bin/id /tmp/id"
        rlRun "machinectl reboot test"
        sleep 15
        rlRun "machinectl status test"
        rlRun "machinectl kill test"
        rlRun "machinectl terminate test"
        rlRun "systemctl stop systemd-nspawn@test"
        # TODO: remove next 2 lines once the BZs are fixed
        rlRun "semodule -r testpolicy"
        rlRun "semodule -lfull | grep testpolicy" 1
        rlRun "rm -rf /var/lib/machines/test"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

