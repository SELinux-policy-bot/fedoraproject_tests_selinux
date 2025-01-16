#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/samba-bgqd-and-similar
#   Description: SELinux interferes with samba-bgqd and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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
SERVICE_PACKAGE="samba"
FILE_PATH="/usr/libexec/samba/samba-bgqd"
PROCESS_NAME="samba-bgqd"
SERVICE_NAME="samba-bgqd"
if seinfo -t | grep -q samba_bgqd ; then
    PROCESS_CONTEXT="samba_bgqd_t"
    FILE_CONTEXT="samba_bgqd_exec_t"
else
    PROCESS_CONTEXT="unconfined_service_t"
    FILE_CONTEXT="bin_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}
        rlAssertRpm cups

        rlFileBackup /etc/shadow
        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if seinfo -t | grep -q samba_bgqd ; then
    rlPhaseStartTest "RHEL-53124 + RHEL-64908"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSEMatchPathCon "/run/samba-bgqd.pid" "samba_bgqd_var_run_t"
        rlSEMatchPathCon "/var/lib/sss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/mc" "sssd_public_t"
        rlSESearchRule "allow winbind_rpcd_t samba_bgqd_var_run_t : file { open write lock } [ ]"
        rlSESearchRule "allow winbind_rpcd_t samba_bgqd_t : unix_dgram_socket { sendto } [ ]"
        rlSESearchRule "allow winbind_rpcd_t samba_bgqd_exec_t : file { getattr open read map execute } [ ]"
        rlSESearchRule "allow samba_bgqd_t sssd_public_t : dir { search } [ ]"
        rlSESearchRule "allow samba_bgqd_t sssd_var_lib_t : dir { search } [ ]"
        rlSESearchRule "allow samba_bgqd_t winbind_rpcd_t : fifo_file { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-69512 + RHEL-69517"
        rlSEMatchPathCon ${FILE_PATH} ${FILE_CONTEXT}
        rlSEMatchPathCon "/etc/cups" "cupsd_etc_t"
        rlSEMatchPathCon "/run/cups" "cupsd_var_run_t"
        rlSESearchRule "allow samba_bgqd_t cupsd_etc_t : dir { search } [ ]"
        rlSESearchRule "allow samba_bgqd_t cupsd_var_run_t : dir { search } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-72860 + RHEL-72861"
        rlSEMatchPathCon "/run/cups/cups.sock" "cupsd_var_run_t"
        rlSESearchRule "allow samba_bgqd_t cupsd_var_run_t : sock_file { read write } [ ]"
        rlSESearchRule "allow samba_bgqd_t cupsd_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario"
        rlRun "service cups start"
        USER_NAME="smbuser${RANDOM}"
        USER_SECRET="S3kr3T${RANDOM}"
        rlRun "useradd ${USER_NAME}"
        rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
        rlRun "echo -en '${USER_SECRET}\n${USER_SECRET}\n' | smbpasswd -s -a ${USER_NAME}"
        rlRun "systemctl start samba-bgqd"
        rlRun "systemctl start smb"
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        sleep 2
        rlRun "rpcclient ncacn_np:localhost -c 'enumprinters' -U${USER_NAME}%${USER_SECRET}"
        sleep 2
        rlRun "systemctl stop smb"
        rlRun "systemctl stop samba-bgqd"
        rlRun "smbpasswd -x ${USER_NAME}"
        rlRun "userdel -rf ${USER_NAME}"
        rlRun "service cups stop"
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

