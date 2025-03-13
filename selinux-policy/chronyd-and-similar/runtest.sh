#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/chronyd-and-similar
#   Description: SELinux interferes with chronyd and related programs
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
SERVICE_PACKAGE="chrony"
SERVICE_NAME="chronyd"
PROCESS_NAME="chronyd"
PROCESS_CONTEXT="chronyd_t"
CHRONYD_RESTRICTED_SERVICE="chronyd-restricted"
CHRONYD_RESTRICTED_UNIT_FILE="/usr/lib/systemd/system/chronyd-restricted.service"
CHRONYD_RESTRICTED_UNIT_DROPIN_DIR="/etc/systemd/system/chronyd-restricted.service.d"
CHRONYD_RESTRICTED_UNIT_DROPIN_FILE="${CHRONYD_RESTRICTED_UNIT_DROPIN_DIR}/context.conf"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop `rlSEListServices 123`
        rlFileBackup /etc/chrony.conf
        rlFileBackup /etc/shadow
        rlFileBackup /etc/chrony.keys

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#974992 + bz#978993"
        rlSEMatchPathCon "/usr/sbin/chronyd" "chronyd_exec_t"
        rlSESearchRule "allow chronyd_t chronyd_t : capability { sys_nice } [ ]"
        rlSESearchRule "allow chronyd_t chronyd_t : process { setsched } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1243764 + bz#1243987"
        rlSEMatchPathCon "/usr/libexec/chrony-helper" "chronyd_exec_t"
        rlSEMatchPathCon "/var/run/chrony-helper" "chronyd_var_run_t"
        rlSEMatchPathCon "/var/run/chrony-helper/added_servers" "chronyd_var_run_t"
        rlSEMatchPathCon "/var/run/chrony-helper/lock" "chronyd_var_run_t"
        rlSEMatchPathCon "/var/lib/dhclient" "dhcpc_state_t"
        rlSEMatchPathCon "/var/lib/dhclient/chrony.servers.eth0" "dhcpc_state_t"
        rlSEMatchPathCon "/usr/bin/systemctl" "systemd_systemctl_exec_t"
        rlSESearchRule "allow dhcpc_t chronyd_exec_t : file { getattr open read execute }"
        rlSESearchRule "type_transition dhcpc_t chronyd_exec_t : process chronyd_t"
        rlSESearchRule "allow dhcpc_t chronyd_t : process { transition }"
        rlSESearchRule "allow chronyd_t var_run_t : dir { read write add_name remove_name search open getattr }"
        rlSESearchRule "type_transition chronyd_t var_run_t : dir chronyd_var_run_t"
        rlSESearchRule "allow chronyd_t chronyd_var_run_t : dir { read write add_name remove_name search open getattr }"
        rlSESearchRule "allow chronyd_t chronyd_var_run_t : file { getattr open read write create unlink }"
        rlSESearchRule "allow chronyd_t dhcpc_state_t : dir { getattr open read search }"
        rlSESearchRule "allow chronyd_t dhcpc_state_t : file { getattr open read }"
        rlSESearchRule "allow chronyd_t bin_t : file { getattr open read execute_no_trans }"
        rlSESearchRule "allow chronyd_t systemd_systemctl_exec_t : file { getattr open read execute_no_trans }"
        rlSESearchRule "allow timemaster_t chronyd_t : process { signal }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1350765"
        rlSESearchRule "allow chronyd_t chronyd_t : capability2 { block_suspend } [ ]"
        rlSESearchRule "allow chronyd_t kernel_t : system { module_request } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1416015 + bz#1421248 + bz#1425408 + bz#1440791"
        rlSEMatchPathCon "/usr/sbin/chronyd" "chronyd_exec_t"
        rlSEMatchPathCon "/etc/adjtime" "adjtime_t"
        rlSEMatchPathCon "/var/run/chrony" "chronyd_var_run_t"
        rlSEMatchPathCon "/var/run/chrony/chronyd.sock" "chronyd_var_run_t"
        rlSEMatchPathCon "/var/run/chrony/chronyc.1117.sock" "chronyd_var_run_t"
        rlSESearchRule "allow chronyd_t adjtime_t : file { getattr open read }"
        rlSESearchRule "allow chronyd_t chronyd_t : capability { chown }"
        rlSESearchRule "allow chronyd_t chronyd_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow chronyd_t chronyd_t : capability { net_admin }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1508486"
        rlSEMatchPathCon "/usr/libexec/chrony-helper" "chronyd_exec_t"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSESearchRule "allow chronyd_t chronyc_exec_t : file { getattr open read execute_no_trans }"
        rlSESearchRule "allow chronyd_t chronyc_t : process { transition }" 1
    rlPhaseEnd

    rlPhaseStartTest "bz#1509379"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSESearchRule "allow chronyc_t chronyc_t : capability { dac_read_search } [ ]"
        rlSESearchRule "type_transition chronyd_t chronyc_exec_t : process chronyc_t" 1
        rlSESearchRule "allow chronyd_t chronyd_t : capability { dac_read_search } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1530525"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSEMatchPathCon "/etc" "etc_t"
        rlSEMatchPathCon "/etc/chrony.keys" "chronyd_keys_t"
#        rlSESearchRule "allow chronyc_t etc_t : dir { write add_name }"
#        rlSESearchRule "type_transition chronyc_t etc_t : file chronyd_keys_t"
        rlSESearchRule "allow chronyc_t chronyd_keys_t : file { getattr ioctl append write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1470150"
        rlSEMatchPathCon "/var/run/chrony" "chronyd_var_run_t"
        rlSEMatchPathCon "/var/run/chrony/chronyc.3781.sock" "chronyd_var_run_t"
        rlSESearchRule "allow chronyd_t chronyc_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow chronyc_t chronyd_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow system_cronjob_t chronyc_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition system_cronjob_t chronyc_exec_t : process chronyc_t"
        rlSESearchRule "allow system_cronjob_t chronyc_t : process { transition } [ ]"
        rlSESearchRule "allow inetd_child_t chronyc_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition inetd_child_t chronyc_exec_t : process chronyc_t"
        rlSESearchRule "allow inetd_child_t chronyc_t : process { transition } [ ]"
        rlSESearchRule "allow chronyc_t chronyd_var_run_t : sock_file { create write unlink }"
    rlPhaseEnd
    fi

    if false ; then
    rlPhaseStartTest "bz#1273116" # CLOSED as NOT-A-BUG, unable to reproduce it anymore
        rlSEMatchPathCon "/usr/lib/systemd/system/chronyd.service" "chronyd_unit_file_t"
        rlSESearchRule "allow chronyd_t chronyd_unit_file_t : service { status }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#1281473"
        rlSEMatchPathCon "/usr/sbin/chronyd" "chronyd_exec_t"
        rlSEMatchPathCon "/etc/chrony.keys" "chronyd_keys_t"
        rlSEMatchPathCon "/var/run/timemaster/chrony.conf" "timemaster_var_run_t"
        rlSESearchRule "allow chronyd_t chronyd_keys_t : file { append setattr }"
        rlSESearchRule "allow chronyd_t timemaster_var_run_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1290310"
        rlSEMatchPathCon "/usr/sbin/chronyd" "chronyd_exec_t"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/chronyd.sock" "chronyd_var_run_t"
        rlSESearchRule "allow chronyd_t var_run_t : dir { getattr open search read write add_name remove_name }"
        rlSESearchRule "type_transition chronyd_t var_run_t : sock_file chronyd_var_run_t"
        rlSESearchRule "allow chronyd_t chronyd_var_run_t : sock_file { create }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1390657"
        rlSEMatchPathCon "/etc/chrony.keys" "chronyd_keys_t"
        rlSESearchRule "allow logrotate_t chronyd_keys_t : file { getattr open read }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1509927"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSESearchRule "allow chronyc_t user_devpts_t : chr_file { read write getattr append open } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1574418"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSEMatchPathCon "/tmp" "tmp_t"
        rlSEMatchPathCon "/var/lib" "var_lib_t"
        rlSEMatchPathCon "/var/lib/check_mk_agent" "var_lib_t"
        rlSEMatchPathCon "/var/lib/check_mk_agent/cache" "var_lib_t"
        rlSEMatchPathCon "/var/lib/check_mk_agent/cache/chrony.cache.new" "var_lib_t"
        rlSEMatchPathCon "/var/log" "var_log_t"
        rlSESearchRule "allow chronyc_t tmp_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition chronyc_t tmp_t : file chronyd_tmp_t"
        rlSESearchRule "allow chronyc_t chronyd_tmp_t : file { create getattr open write } [ ]"
        rlSESearchRule "allow chronyc_t var_log_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition chronyc_t var_log_t : file chronyd_var_log_t"
        rlSESearchRule "allow chronyc_t chronyd_var_log_t : file { create getattr open write } [ ]"
        rlSESearchRule "allow chronyc_t var_lib_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition chronyc_t var_lib_t : file chronyd_var_lib_t"
        rlSESearchRule "allow chronyc_t chronyd_var_lib_t : file { create getattr open write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1575002 + bz#1577057 + bz#1593267"
        rlSEMatchPathCon "/dev/tty1" "tty_device_t"
        rlSESearchRule "allow unconfined_t chronyc_exec_t : file { getattr open read execute }"
        rlSESearchRule "allow unconfined_t chronyc_t : process { transition }"
        rlSESearchRule "type_transition unconfined_t chronyc_exec_t : process chronyc_t"
        rlSESearchRule "type_change unconfined_t tty_device_t : chr_file user_tty_device_t"
        rlSESearchRule "allow chronyc_t user_tty_device_t : chr_file { read write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1596563"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSEMatchPathCon "/var/run/nscd/socket" "nscd_var_run_t"
        rlSEMatchPathCon "/var/db/nscd/passwd" "nscd_var_run_t"
        rlSESearchRule "allow chronyc_t nscd_t : unix_stream_socket { connectto }"
        rlSESearchRule "allow system_dbusd_t nscd_var_run_t : file { map }"
        rlSESearchRule "dontaudit chronyc_t nscd_var_run_t : file { getattr open read }"
        rlSESearchRule "allow chronyd_t chronyd_tmpfs_t : file { map }"
        rlSESearchRule "allow chronyd_t gpsd_tmpfs_t : file { map }"
        rlSESearchRule "allow chronyc_t nscd_t : nscd { shmemhost gethost }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1568281"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSEMatchPathCon "/run/chrony" "chronyd_var_run_t"
        rlSESearchRule "allow logrotate_t chronyc_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition logrotate_t chronyc_exec_t : process chronyc_t"
        rlSESearchRule "allow logrotate_t chronyc_t : process { transition } [ ]"
        rlSESearchRule "allow chronyc_t chronyd_var_run_t : dir { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1567753"
        rlSEMatchPathCon "/usr/sbin/chronyd" "chronyd_exec_t"
        rlSEMatchPathCon "/var/lib/libvirt/dnsmasq" "virt_var_lib_t"
        rlSESearchRule "allow chronyd_t virt_var_lib_t : dir { getattr open search read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1618757 + bz#1622499"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSESearchRule "allow chronyc_t unconfined_t : unix_stream_socket { read write ioctl getattr } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    # bz#1652079 was closed as WONTFIX
    rlPhaseStartTest "bz#1652079 + bz#1696252"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSEMatchPathCon "/var/lib" "var_lib_t"
        rlSEMatchPathCon "/var/lib/test" "var_lib_t"
        rlSEMatchPathCon "/var/log" "var_log_t"
        rlSEMatchPathCon "/var/log/test" "var_log_t"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/test" "var_run_t"
        rlSEMatchPathCon "/var/cache" "var_t"
        rlSEMatchPathCon "/var/cache/test" "var_t"
        rlSESearchRule "allow chronyc_t var_lib_t : dir { getattr open search write add_name } [ ]"
        rlSESearchRule "allow chronyc_t var_lib_t : file { getattr ioctl write append } [ ]"
        rlSESearchRule "allow chronyc_t var_log_t : dir { getattr open search write add_name } [ ]"
        rlSESearchRule "allow chronyc_t var_log_t : file { getattr ioctl write append } [ ]"
        rlSESearchRule "allow chronyc_t var_t : file { getattr ioctl write append } [ ]"
        rlSESearchRule "allow chronyc_t var_run_t : file { getattr ioctl write append } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1593607"
        rlSEMatchPathCon "/usr/libexec/chrony-helper" "chronyd_exec_t"
        rlSESearchRule "allow chronyd_t shell_exec_t : file { map } [ ] mls"
    rlPhaseEnd

    rlPhaseStartTest "bz#1772852"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSEMatchPathCon "/var/db/nscd/hosts" "nscd_var_run_t"
        rlSESearchRule "allow chronyc_t nscd_var_run_t : file { map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 8 ; then
    rlPhaseStartTest "bz#1895825"
        rlSEMatchPathCon "/run/chrony-dhcp" "chronyd_var_run_t"
        rlSEMatchPathCon "/run/chrony-dhcp/something.source" "chronyd_var_run_t"
    rlPhaseEnd

    rlPhaseStartTest "bz#1900143"
        rlSEMatchPathCon "/run/systemd/resolve/io.systemd.Resolve" "systemd_resolved_var_run_t"
        rlSESearchRule "allow chronyd_t systemd_resolved_var_run_t : sock_file { write } [ ]"
        # rlRun "grep resolve /etc/nsswitch.conf"
    rlPhaseEnd

    rlPhaseStartTest "bz#2173604"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlRun "ls -dZ /proc/sys/net/ipv6/conf/all | grep :sysctl_net_t"
        rlRun "ls -dZ /proc/sys/net/ipv6/conf/all/disable_ipv6 | grep :sysctl_net_t"
        rlSESearchRule "allow chronyc_t sysctl_net_t : dir { search } [ ]"
        rlSESearchRule "allow chronyc_t sysctl_net_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1961207"
        rlSEMatchPortCon tcp 4460 ntske_port_t
        rlSEMatchPathCon "/usr/share/pki/ca-trust-source/ca-bundle.trust.p11-ki" "cert_t"
        rlSESearchRule "allow chronyd_t ntske_port_t : tcp_socket { name_bind name_connect } [ ]"
        rlSESearchRule "allow chronyd_t chronyd_t : tcp_socket { listen accept }"
        rlSESearchRule "allow chronyd_t cert_t : file { map } [ ]"
    rlPhaseEnd
    fi

    if rlIsFedora ; then
    rlPhaseStartTest "bz#2008894"
        rlSEMatchPathCon "/usr/bin/chronyc" "chronyc_exec_t"
        rlSESearchRule "allow init_t chronyc_t : process2 { nnp_transition } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- chrony-wait service"
        rlServiceStop chrony-wait
        rlRun "mkdir -p /run/systemd/system/chrony-wait.service.d"
        rlRun "echo -e '[Service]\nDynamicUser=yes' > /run/systemd/system/chrony-wait.service.d/override.conf"
        rlRun "systemctl daemon-reload"
        rlRun "systemctl start chrony-wait.service"
        sleep 5
        rlRun "systemctl stop chrony-wait.service"
        rlRun "rm -f /run/systemd/system/chrony-wait.service.d/override.conf"
        rlRun "systemctl daemon-reload"
        rlServiceRestore chrony-wait
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlRun "echo \"sched_priority 50\" >> /etc/chrony.conf"
        rlRun "echo \"refclock SHM 0\" >> /etc/chrony.conf"
        rlRun "echo \"refclock SOCK /var/run/chronyd.sock\" >> /etc/chrony.conf"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        if ! rlIsFedora ; then
            rlRun "ipcs -m | grep 0x4e545030"
            rlRun "ls -Z /var/run/chronyd.sock | grep :chronyd_var_run_t"
        fi
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
        rlRun "chronyc tracking"
        for OUTPUT_FILE in /tmp/chronyc.output /var/lib/chrony/chronyc.output /var/log/chrony/chronyc.output ; do
             rlRun "rm -f ${OUTPUT_FILE}"
             rlRun "chronyc tracking > ${OUTPUT_FILE}"
             rlRun "test -s ${OUTPUT_FILE}"
             rlRun "ls -Z ${OUTPUT_FILE} | grep -e :user_tmp_t -e :chronyd_var_lib_t -e :chronyd_var_log_t"
        done
        if ! rlIsRHEL 7 ; then
            for OUTPUT_FILE in /var/lib/test /var/log/test /var/run/test /var/cache/test ; do
                rlRun "rm -f ${OUTPUT_FILE}"
                rlRun "chronyc -n tracking > ${OUTPUT_FILE}"
                rlRun "test -s ${OUTPUT_FILE}"
                rlRun "chronyc -n tracking >> ${OUTPUT_FILE}"
                rlRun "ls -Z ${OUTPUT_FILE}"
                rlRun "ls -Z ${OUTPUT_FILE} | grep -e :var_lib_t -e :var_log_t -e :var_run_t -e :var_t"
                rlRun "rm -f ${OUTPUT_FILE}"
            done
        fi
        if rpm -q nscd >& /dev/null ; then
            rlRun "service nscd start"
        fi
        sleep 2
        rlRun "getsebool -a | grep nscd"
        rlRun "chronyc sources"
        rlRun "ksh -c \"chronyc sources\""
        if ! rlIsRHEL 5 6 ; then
            rlRun "chronyc serverstats"
        fi
        if rpm -q nscd >& /dev/null ; then
            rlRun "service nscd stop"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "real scenario -- bz#1530525"
        rlRun "rm -f /etc/chrony.keys"
        rlRun "touch /etc/chrony.keys"
        rlRun "restorecon -v /etc/chrony.keys"
        rlRun "chronyc keygen 1111 SHA1 > /etc/chrony.keys"
        rlRun "chronyc keygen 1111 SHA1 >> /etc/chrony.keys"
        rlRun "ls -Z /etc/chrony.keys | grep :chronyd_keys_t"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "real scenario -- bz#1961207"
        rlRun "./chrony-nts-test.sh"
        rlRun "rm -f /var/lib/chrony/*.nts"
        rlRun "systemctl restart chronyd"
    rlPhaseEnd

    rlPhaseStartTest "bz#2065313"
        rlSESearchRule "allow chronyd_t unconfined_t : unix_dgram_socket { sendto }"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#2065313"
        rlLog "special socat command talks to chronyd via its UNIX socket"
        printf "\x6\x1\x0\x0\x0\x21\x0\x0\x21\xd7\xe4\x22\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0" | socat unix-sendto:/run/chrony/chronyd.sock,bind=/run/chrony/chronyc.sock,umask=0000 - | hexdump -C
    rlPhaseEnd

    rlPhaseStartTest "bz#2118628 + bz#2118631"
        rlSEMatchPortCon udp 319 ptp_event_port_t
        rlSESearchRule "allow chronyd_t ptp_event_port_t : udp_socket { name_bind } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#2118628 + bz#2118631"
        rlRun "echo -en '\nallow\nptpport 319\nserver 127.0.0.1 port 319 minpoll 0 maxpoll 0\n' >> /etc/chrony.conf"
        rlRun "systemctl restart chronyd"
        sleep 5
        rlRun "chronyc ntpdata 127.0.0.1 | grep 'Total RX'"
    rlPhaseEnd
    fi

    if rlSEDefined "chronyd_restricted_t" ; then
    rlPhaseStartTest "RHEL-82299 + RHEL-82308"
        rlSESearchRule "allow chronyc_t chronyd_restricted_t : unix_dgram_socket { sendto } [ ]"
        rlSESearchRule "allow chronyd_restricted_t chronyc_t : unix_dgram_socket { sendto } [ ]"
    rlPhaseEnd
    fi

    if [ -f ${CHRONYD_RESTRICTED_UNIT_FILE} ]; then
      rlPhaseStartTest "chronyd-restricted -- bz#2169949 + RHEL-18219"
        rlRun "systemctl stop ${SERVICE_NAME}"
        rlRun "mkdir -p ${CHRONYD_RESTRICTED_UNIT_DROPIN_DIR}"
        if ! grep ^SELinuxContext= ${CHRONYD_RESTRICTED_UNIT_FILE} ; then
            # temporary configuration change until it becomes a part of the chrony package
            rlRun "echo -e '[Service]\nSELinuxContext=system_u:system_r:chronyd_restricted_t:s0\n' > ${CHRONYD_RESTRICTED_UNIT_DROPIN_FILE}"
            rlRun "systemctl daemon-reload"
        fi
        rlRun "systemctl start ${CHRONYD_RESTRICTED_SERVICE}"
        sleep 3
        rlRun "ps -o pid,uid,command,context -C chronyd | grep -1 system_u:system_r:chronyd_restricted_t:"
        rlRun "systemctl status ${CHRONYD_RESTRICTED_SERVICE}"
        rlRun "chronyc reload sources" 0,1
        rlRun "systemctl restart ${CHRONYD_RESTRICTED_SERVICE}"
        rlRun "systemctl status ${CHRONYD_RESTRICTED_SERVICE}"
        rlRun "systemctl stop ${CHRONYD_RESTRICTED_SERVICE}"
        rlRun "rm -f ${CHRONYD_RESTRICTED_UNIT_DROPIN_FILE}"
        rlRun "systemctl daemon-reload"
      rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlRun "rm -f /tmp/chronyc.output /var/lib/chrony/chronyc.output /var/log/chrony/chronyc.output"
        rlFileRestore
        rlServiceRestore `rlSEListServices 123`
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

