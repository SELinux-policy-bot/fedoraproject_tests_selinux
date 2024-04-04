#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bz562833-chrooted-named-file-contexts
#   Description: some named files in chroot-ed environment have wrong SELinux labels
#   Author: Milos Malik <mmalik@redhat.com>
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
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm bind

        rlServiceStop ` rlSEListServices 53 `
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#451970"
        rlSEMatchPathCon "/usr/sbin/named" "named_exec_t"
        rlSESearchRule "allow named_t port_t : udp_socket { name_bind }"
    rlPhaseEnd

    rlPhaseStartTest "bz#562833"
        for PREFIX in "" "/var/named/chroot" ; do
            rlSEMatchPathCon "${PREFIX}/dev/null" "null_device_t"
            rlSEMatchPathCon "${PREFIX}/dev/random" "random_device_t"
            rlSEMatchPathCon "${PREFIX}/dev/zero" "zero_device_t"
            rlSEMatchPathCon "${PREFIX}/etc/named.conf" "named_conf_t"
            rlSEMatchPathCon "${PREFIX}/var/log" "var_log_t"
            rlSEMatchPathCon "${PREFIX}/var/log/named.log" "named_log_t"
            rlSEMatchPathCon "${PREFIX}/var/named/data" "named_cache_t"
            rlSEMatchPathCon "${PREFIX}/var/named/slaves" "named_cache_t"
            rlSEMatchPathCon "${PREFIX}/var/named" "named_zone_t"
            rlSEMatchPathCon "${PREFIX}/var/run/named" "named_var_run_t"
        done
    rlPhaseEnd

    rlPhaseStartTest "bz#578187"
        rlSEMatchPathCon "/usr/sbin/named" "named_exec_t"
        for PREFIX in "" "/var/named/chroot" ; do
            rlSEMatchPathCon "${PREFIX}/var/named/dynamic" "named_cache_t"
        done
        rlSESearchRule "allow named_t named_t : process { getcap setcap getsched setsched setrlimit }"
    rlPhaseEnd

    rlPhaseStartTest "bz#698257"
        rlSEMatchPathCon "/usr/sbin/named" "named_exec_t"
        if rlIsRHEL 5 ; then
            rlSEMatchPathCon "/var/named/chroot/var/log/update-debug.log" "named_log_t"
        fi
        rlSESearchRule "allow named_t named_log_t : file { append }"
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
        rlPhaseStartTest "bz#739886"
            rlSEMatchPathCon "/usr/sbin/rndc" "ndc_exec_t"
            rlRun "ls -Z /proc/loadavg | grep :proc_t"
            rlSESearchRule "allow ndc_t proc_t : file { getattr open read }"
        rlPhaseEnd

        rlPhaseStartTest "bz#843732 + bz#916173"
            for PREFIX in "" "/var/named/chroot" ; do
                rlSEMatchPathCon "${PREFIX}/lib" "lib_t"
                rlSEMatchPathCon "${PREFIX}/lib64" "lib_t"
                rlSEMatchPathCon "${PREFIX}/usr/lib" "lib_t"
                rlSEMatchPathCon "${PREFIX}/usr/lib64" "lib_t"
            done
            rlSEMatchPathCon "/var/named/chroot/etc/localtime" "locale_t"
        rlPhaseEnd

        rlPhaseStartTest "bz#1110397 + bz#1166281"
            rlSEMatchPathCon "/usr/sbin/rndc" "ndc_exec_t"
            rlSEMatchPathCon "/dev/random" "random_device_t"
            rlSEMatchPathCon "/dev/urandom" "urandom_device_t"
            rlSESearchRule "allow ndc_t random_device_t : chr_file { getattr open read }"
            rlSESearchRule "allow ndc_t urandom_device_t : chr_file { getattr open read }"
        rlPhaseEnd
    fi

    if rlIsRHEL 6 ; then
        rlPhaseStartTest "bz#859231"
            rlSEMatchPathCon "/var/tmp/DNS_25" "named_tmp_t"
        rlPhaseEnd

        rlPhaseStartTest "bz#1103439 + bz#1199473"
            rlSEMatchPathCon "/usr/sbin/named" "named_exec_t"
            rlSEMatchPortCon udp 1935 flash_port_t
            rlSEMatchPortCon udp 2605 bgp_port_t
            rlSEMatchPortCon udp 4321 whois_port_t
            rlSEMatchPortCon udp 6514 syslogd_port_t
            rlSEMatchPortCon udp 8610 ipp_port_t
            rlSEMatchPortCon udp 8611 ipp_port_t
            rlSEMatchPortCon udp 8612 ipp_port_t
            rlSEMatchPortCon udp 8613 ipp_port_t
            rlSEMatchPortCon udp 8614 ipp_port_t
            rlSESearchRule "dontaudit named_t flash_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "dontaudit named_t ipp_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "dontaudit named_t syslogd_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "dontaudit named_t whois_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "dontaudit named_t bgp_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t reserved_port_t : udp_socket { name_bind } [ ]" 1
            rlSESearchRule "allow named_t hi_reserved_port_t : udp_socket { name_bind } [ ]" 1
            rlSESearchRule "dontaudit named_t reserved_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "dontaudit named_t hi_reserved_port_t : udp_socket { name_bind } [ ]"
        rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
        rlPhaseStartTest "bz#1012051"
            rlSEMatchPathCon "/usr/sbin/named" "named_exec_t"
            rlSESearchRule "allow named_t named_t : key { read write }"
        rlPhaseEnd

        rlPhaseStartTest "bz#1312972"
            rlSEMatchPortCon udp 1935 flash_port_t
            rlSEMatchPortCon udp 2605 bgp_port_t
            rlSEMatchPortCon udp 4321 whois_port_t
            rlSEMatchPortCon udp 4444 kerberos_port_t
            rlSEMatchPortCon udp 5546 dhcpc_port_t
            if rlIsRHEL 7 ; then
                rlSEMatchPortCon udp 61000 ephemeral_port_t
            else # RHEL-8 and Fedora
                rlSEMatchPortCon udp 60999 ephemeral_port_t
            fi
            rlSEMatchPortCon udp 8554 rtsp_port_t
            rlSEMatchPortCon udp 8610 ipp_port_t
            rlSEMatchPortCon udp 8611 ipp_port_t
            rlSEMatchPortCon udp 8612 ipp_port_t
            rlSEMatchPortCon udp 8613 ipp_port_t
            rlSEMatchPortCon udp 8614 ipp_port_t
            rlSESearchRule "allow named_t bgp_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t dhcpc_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t ephemeral_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t flash_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t ipp_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t kerberos_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t rtsp_port_t : udp_socket { name_bind } [ ]"
            rlSESearchRule "allow named_t whois_port_t : udp_socket { name_bind } [ ]"
            COUNT=`seinfo --portcon | cut -d : -f 3 | sort | uniq | wc -l`
            rlLog "Number of defined SELinux ports which have at least 1 port number assigned is $COUNT"
            for PORT_TYPE in `seinfo --portcon | cut -d : -f 3 | sort | uniq` ; do
               if rlIsRHEL 5 6 7 ; then
                   sesearch -s named_t -t ${PORT_TYPE} -c udp_socket -p name_bind -A -C -D | grep -v '\]' | grep -q -e allow -e dontaudit
               else
                   sesearch -s named_t -t ${PORT_TYPE} -c udp_socket -p name_bind -A --dontaudit | grep -v '\]' | grep -q -e allow -e dontaudit
               fi
               if [ $? -eq 1 ] ; then
                   rlFail "named_t access to ${PORT_TYPE}:udp_socket via name_bind operation is neither allowed nor dontaudited"
               fi
            done
            rlLog "all $COUNT defined SELinux ports tested"
        rlPhaseEnd

        rlPhaseStartTest "bz#1683754"
            rlRun "ls -dZ /proc/sys/net | grep :sysctl_net_t"
            rlRun "ls -dZ /proc/sys/net/ipv4 | grep :sysctl_net_t"
            rlRun "ls -Z /proc/sys/net/ipv4/ip_local_port_range | grep :sysctl_net_t"
            rlSESearchRule "allow named_t sysctl_net_t : dir { getattr open search } [ ]"
            rlSESearchRule "allow named_t sysctl_net_t : file { getattr open read } [ ]"
        rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
        rlPhaseStartTest "bz#1759505"
            rlSEMatchPathCon "/etc/named" "named_conf_t"
            rlSEMatchPathCon "/etc/named/test.conf" "named_conf_t"
        rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 8 && ! rlIsCentOS 5 6 7 8 ; then
        rlPhaseStartTest "bz#1827591 + bz#1923929"
            rlSEMatchPathCon "/usr/sbin/rndc" "ndc_exec_t"
            rlSESearchRule "dontaudit ndc_t ndc_t : process { setsched } [ ]"
        rlPhaseEnd
    fi

    if rlIsFedora '>=38' ; then
        rlPhaseStartTest "bz#2223725 + bz#2224352 + bz#2226703"
            rlSESearchRule "allow named_t named_t : io_uring { sqpoll } [ ]"
            rlSESearchRule "allow ndc_t ndc_t : io_uring { sqpoll } [ ]"
        rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        if ! rlIsRHEL 5 ; then
            rlRun "semodule -l | grep bind"
        fi
        rlRun "getsebool -a | grep named"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlSEService ${ROOT_PASSWORD} named named named_t "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlRun "runcon system_u:system_r:initrc_t:s0 bash -c 'rndc querylog'"
        rlRun "runcon system_u:system_r:initrc_t:s0 bash -c 'rndc dumpdb'"
        rlRun "runcon system_u:system_r:initrc_t:s0 bash -c 'rndc tsig-list'"
        rlSEService ${ROOT_PASSWORD} named named named_t "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ` rlSEListServices 53 `
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

