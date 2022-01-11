#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/smbcontrol-and-similar
#   Description: SELinux interferes with smbcontrol and related programs
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
FILE_PATH="/usr/bin/smbcontrol"
FILE_CONTEXT="smbcontrol_exec_t"
if rlIsRHEL 6 ; then
    SERVICE_PACKAGE="samba-common"
else
    SERVICE_PACKAGE="samba-common-tools"
fi
PROCESS_NAME="smbcontrol"
PROCESS_CONTEXT="smbcontrol_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1326371 + bz#1326621"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        SOURCE_TYPE="unconfined_t"
        BOOLEANS="[ ]"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlSESearchRule "allow smbcontrol_t samba_var_t : dir { ioctl read write getattr lock add_name remove_name search open }"
        rlSESearchRule "allow smbcontrol_t samba_var_t : file { ioctl read write create getattr setattr lock append unlink link rename open }"
        rlSESearchRule "allow smbcontrol_t samba_var_t : sock_file { ioctl read write create getattr setattr lock append unlink link rename open }"
        rlSESearchRule "allow smbd_t smbcontrol_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow smbcontrol_t smbd_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow nmbd_t smbcontrol_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow smbcontrol_t nmbd_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow winbind_t smbcontrol_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow smbcontrol_t winbind_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow smbcontrol_t smbcontrol_t : unix_dgram_socket { create ioctl read getattr lock write setattr append bind connect getopt setopt shutdown }"
        rlSESearchRule "allow smbcontrol_t smbcontrol_t : process { signal signull }"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1574518 + bz#1574521"
        rlSEMatchPathCon "/usr/bin/smbcontrol" "smbcontrol_exec_t"
        rlSEMatchPathCon "/var/lib/samba/lock" "samba_var_t"
        # following rule assumes that samba_var_lock_t type is not defined
        rlSESearchRule "allow smbcontrol_t samba_var_t : dir { create add_name write }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#2025931 + bz#2027740 + bz#2027751"
        rlSESearchRule "allow smbcontrol_t smbcontrol_t : netlink_route_socket { create bind getattr nlmsg_read} [ ]"
        rlSESearchRule "allow smbcontrol_t smbcontrol_t : udp_socket { create ioctl } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2033873 + bz#2038157 + bz#2038963"
        rlRun "ls -Z /proc/net/unix | grep :proc_net_t"
        rlSESearchRule "allow smbcontrol_t proc_net_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        if ! rlIsRHEL 5 6 ; then
            rlRun "ls -Z /var/lib/samba/lock"
        fi
        rlRun "smbcontrol nmbd ping" 0,1
        rlRun "smbcontrol smbd ping" 0,1
        rlRun "smbcontrol winbindd ping" 0,1
        if ! rlIsRHEL 5 6 ; then
            rlRun "ls -Z /var/lib/samba/lock"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

