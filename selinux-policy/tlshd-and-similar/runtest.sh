#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/tlshd-and-similar
#   Description: SELinux interferes with tlshd and related programs
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
FILE_PATH="/usr/sbin/tlshd"
SERVICE_PACKAGE="ktls-utils"
SERVICE_NAME="tlshd"
PROCESS_NAME="tlshd"
if seinfo -t | grep -q tlshd ; then
    PROCESS_CONTEXT="ktlshd_t"
    FILE_CONTEXT="ktlshd_exec_t"
else
    PROCESS_CONTEXT="unconfined_service_t"
    FILE_CONTEXT="bin_t"
fi

rlJournalStart
    if rlIsRHEL 7 8 || rlIsCentOS 7 8 ; then
        rlLog "Not applicable to this OS version."
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

    rlPhaseStartTest "RHEL-29439 + RHEL-42672"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow init_t ${PROCESS_CONTEXT} : process { transition } [ ]"
        rlSESearchRule "type_transition init_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
    rlPhaseEnd

    if rlSEDefined "ktlshd_t" ; then
    rlPhaseStartTest "RHEL-74424"
        rlSEMatchPathCon "/etc/resolv.conf" "net_conf_t"
        rlSEMatchPathCon "/etc/pki/tls/certs/ca-cert.pem" "cert_t"
        rlRun "ls -Z /proc/net/if_inet6 | grep :proc_net_t"
        rlRun "ls -Z /proc/sys/net/ipv6/conf/all/disable_ipv6 | grep :sysctl_net_t"
        rlSESearchRule "allow ktlshd_t ktlshd_t : key { write } [ ]"
        rlSESearchRule "allow ktlshd_t cert_t : dir { search } [ ]"
        rlSESearchRule "allow ktlshd_t cert_t : file { getattr open read } [ ]"
        rlSESearchRule "allow ktlshd_t net_conf_t : file { getattr open read } [ ]"
        # rlSESearchRule "allow ktlshd_t proc_net_t : lnk_file { read } [ ]"
        rlSESearchRule "allow ktlshd_t ktlshd_t : netlink_route_socket { bind create getattr getopt nlmsg_read setopt } [ ]"
        rlSESearchRule "allow ktlshd_t ktlshd_t : udp_socket { connect create getattr setopt } [ ]"
        rlSESearchRule "allow ktlshd_t sysctl_net_t : dir { search } [ ]"
        rlSESearchRule "allow ktlshd_t sysctl_net_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

