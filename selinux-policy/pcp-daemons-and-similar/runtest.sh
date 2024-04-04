#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/pcp-daemons-and-similar
#   Description: the services were running as initrc_t, now they are confined by SELinux
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

SERVICE_NAMES="pmcd pmlogger pmie pmproxy"
SERVICE_PACKAGE="pcp"

TRIPLETSLIST="
    /usr/libexec/pcp/bin/pmcd:pcp_pmcd_exec_t:pcp_pmcd_t:pmcd 
    /usr/bin/pmie:pcp_pmie_exec_t:pcp_pmie_t:pmie
    /usr/bin/pmlogger:pcp_pmlogger_exec_t:pcp_pmlogger_t:pmlogger
    /usr/libexec/pcp/bin/pmproxy:pcp_pmproxy_exec_t:pcp_pmproxy_t:pmproxy
"
PCPVER="$(rpm -q --qf '%{version}' pcp)"

if rlIsRHEL '<8.2'; then
    # pmwebd has been retired in RHEL >= 8.2 (pcp-5.0.0)
    SERVICE_NAMES="${SERVICE_NAMES} pmwebd"
fi
#if rlIsRHEL '<8.4'; then
if rlTestVersion "${PCPVER}" "<" "5.2.0" ; then
    # pmmgr has been retired in RHEL >= 8.4 (pcp-5.2.0)
    TRIPLETSLIST="
        ${TRIPLETSLIST}
        /usr/libexec/pcp/bin/pmmgr:pcp_pmmgr_exec_t:pcp_pmmgr_t:pmmgr
    "
    SERVICE_NAMES="${SERVICE_NAMES} pmmgr"
fi
SEDEFINED="pcp_pmcd_t pcp_pmie_t pcp_pmlogger_t pcp_pmmgr_t pcp_pmproxy_t"
if rlIsRHEL '<8.2' ; then
    if ! rlCheckRpm "pcp-webapi"; then
        rlRpmInstall "pcp-webapi"
    fi
    TRIPLETSLIST="
        ${TRIPLETSLIST}
        /usr/libexec/pcp/bin/pmwebd:pcp_pmwebd_exec_t:pcp_pmwebd_t:pmwebd
    "
    SEDEFINED="${SEDEFINED} pcp_pmwebd_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}
        rlAssertRpm "pcp-pmda-dm"

        rlServiceStop ${SERVICE_NAMES}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#1028598"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="initrc_t"
            BOOLEANS="[ ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        for TRIPLET in ${TRIPLETSLIST} ; do
            FILE_PATH=`echo ${TRIPLET} | cut -d : -f 1`
            FILE_CONTEXT=`echo ${TRIPLET} | cut -d : -f 2`
            PROCESS_CONTEXT=`echo ${TRIPLET} | cut -d : -f 3`
            rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
            rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute }"
            rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition }"
            rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
        done
        rlSEMatchPathCon "/var/run/pcp" "pcp_var_run_t"
        rlSEMatchPathCon "/var/run/pcp/pmcd.socket" "pcp_var_run_t"
        rlSEMatchPathCon "/dev/log" "devlog_t"
        rlSEMatchPathCon "/dev/mapper/control" "lvm_control_t"
        rlSEMatchPortCon tcp 4330 dey_sapi_port_t
        if rlIsRHEL 6 ; then
            rlSEMatchPortCon tcp 4331 commplex_port_t
        else
            rlRun "ls -Z /proc/sys/fs/file-nr | grep :sysctl_fs_t"
            # modprobe nfsd
            # rlRun "ls -Z /proc/net/rpc/nfsd | grep :sysctl_rpc_t"
            rlSEMatchPortCon tcp 4331 commplex_link_port_t
            rlSEMatchPortCon tcp 44321 ephemeral_port_t
        fi
        rlSESearchRule "allow pcp_pmcd_t cgroup_t : dir { getattr }"
        rlSESearchRule "allow pcp_pmcd_t devlog_t : sock_file { write }"
        rlSESearchRule "allow pcp_pmcd_t fixed_disk_device_t : blk_file { getattr }"
        rlSESearchRule "allow pcp_pmcd_t fs_t : filesystem { getattr }"
        rlSESearchRule "allow pcp_pmcd_t kernel_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow pcp_pmcd_t lvm_control_t : chr_file { getattr }"
        rlSESearchRule "allow pcp_pmcd_t pcp_pmcd_t : tcp_socket { accept }"
        rlSESearchRule "allow pcp_pmcd_t pcp_var_run_t : sock_file { create setattr }"
        rlSESearchRule "allow pcp_pmcd_t sysctl_fs_t : dir { search }"
        rlSESearchRule "allow pcp_pmcd_t sysctl_fs_t : file { getattr open read }"
        rlSESearchRule "allow pcp_pmcd_t sysctl_rpc_t : dir { search }"
        rlSESearchRule "allow pcp_pmcd_t sysctl_rpc_t : file { getattr open read }"
        if ! rlIsRHEL 6 ; then
            rlSESearchRule "allow pcp_pmie_t ephemeral_port_t : tcp_socket { name_connect }"
        fi
        rlSESearchRule "allow pcp_pmie_t etc_runtime_t : file { getattr open read }"
        rlSESearchRule "allow pcp_pmie_t pcp_pmcd_t : unix_stream_socket { connectto }"
        rlSESearchRule "allow pcp_pmie_t pcp_pmie_t : netlink_route_socket { bind create getattr nlmsg_read }"
        rlSESearchRule "allow pcp_pmie_t devlog_t : sock_file { write }"
        rlSESearchRule "allow pcp_pmie_t kernel_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow pcp_pmie_t pcp_pmie_t : unix_dgram_socket { create connect }"
        rlSESearchRule "allow pcp_pmlogger_t dey_sapi_port_t : tcp_socket { name_bind }"
        rlSESearchRule "allow pcp_pmlogger_t pcp_pmlogger_t : netlink_route_socket { bind create getattr nlmsg_read }"
        rlSESearchRule "allow pcp_pmlogger_t node_t : tcp_socket { node_bind }"
        rlSESearchRule "allow pcp_pmlogger_t pcp_pmcd_t : unix_stream_socket { connectto }"
        rlSESearchRule "allow pcp_pmlogger_t pcp_pmlogger_t : process { setpgid }"
        if rlIsRHEL '<8.4'; then # pmmgr has been retired in RHEL >= 8.4 (pcp-5.2.0)
            rlSESearchRule "allow pcp_pmmgr_t devlog_t : sock_file { write }"
            rlSESearchRule "allow pcp_pmmgr_t dey_sapi_port_t : tcp_socket { name_bind }"
            if rlIsRHEL 6 ; then
                rlSESearchRule "allow pcp_pmmgr_t commplex_port_t : tcp_socket { name_bind }"
            else
                rlSESearchRule "allow pcp_pmmgr_t commplex_link_port_t : tcp_socket { name_bind }"
                rlSESearchRule "allow pcp_pmmgr_t ephemeral_port_t : tcp_socket { name_connect }"
            fi
            rlSESearchRule "allow pcp_pmmgr_t fs_t : filesystem { getattr }"
            rlSESearchRule "allow pcp_pmmgr_t kernel_t : unix_dgram_socket { sendto }"
            rlSESearchRule "allow pcp_pmmgr_t pcp_pmcd_t : unix_stream_socket { connectto }"
            rlSESearchRule "allow pcp_pmmgr_t pcp_pmie_exec_t : file { getattr open read execute }"
            rlSESearchRule "allow pcp_pmmgr_t pcp_pmlogger_exec_t : file { read execute open execute_no_trans }"
            rlSESearchRule "allow pcp_pmmgr_t pcp_pmmgr_t : tcp_socket { listen }"
            rlSESearchRule "allow pcp_pmmgr_t pcp_pmmgr_t : unix_dgram_socket { create connect }"
            rlSESearchRule "allow pcp_pmmgr_t pcp_var_run_t : sock_file { write }"
        fi
        rlSESearchRule "allow pcp_pmproxy_t devlog_t : sock_file { write }"
        rlSESearchRule "allow pcp_pmproxy_t kernel_t : unix_dgram_socket { sendto }"
        rlSESearchRule "allow pcp_pmproxy_t pcp_pmproxy_t : unix_dgram_socket { create connect }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1061159 + bz#1064233 + bz#1130934"
        rlSEMatchPathCon "/usr/libexec/postfix/local" "postfix_local_exec_t"
        rlSEMatchPathCon "/var/lib/pcp" "pcp_var_lib_t"
        rlSEMatchPathCon "/var/lib/pcp/.forward" "pcp_var_lib_t"
        rlSESearchRule "allow postfix_local_t pcp_var_lib_t : dir { getattr open search }"
        rlSESearchRule "allow postfix_local_t pcp_var_lib_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1072785"
        rlSEMatchPathCon "/bin/bash" "shell_exec_t"
        rlSEMatchPathCon "/etc/pcp/pmcd/pmcd.conf" "etc_t"
        rlSEMatchPathCon "/var/run/pcp/pmcd.socket" "pcp_var_run_t"
        rlSEMatchPathCon "/var/run/utmp" "initrc_var_run_t"
        rlSEMatchPortCon tcp 5671 amqp_port_t
        if rlIsRHEL 6 ; then
            rlSEMatchPortCon tcp 4331 commplex_port_t
        else
            rlSEMatchPortCon tcp 4331 commplex_link_port_t
            rlSEMatchPortCon tcp 44321 ephemeral_port_t
        fi
        rlSESearchRule "allow pcp_pmcd_t pcp_tmp_t : sock_file { create write unlink }"
        rlSESearchRule "allow pcp_pmcd_t amqp_port_t : tcp_socket { name_bind name_connect }"
        rlSESearchRule "allow pcp_pmcd_t domain : process { getattr }"
        rlSESearchRule "allow pcp_pmcd_t etc_t : file { open }"
        rlSESearchRule "allow pcp_pmcd_t initrc_var_run_t : file { getattr open read lock }"
        rlSESearchRule "allow pcp_pmcd_t kernel_t : system { ipc_info }"
        rlSESearchRule "allow pcp_pmcd_t pcp_pmcd_t : unix_stream_socket { connectto }"
        rlSESearchRule "allow pcp_pmcd_t pcp_var_run_t : sock_file { create write }"
        rlSESearchRule "allow pcp_pmie_t bin_t : file { getattr open read execute }"
        rlSESearchRule "allow pcp_pmie_t pcp_tmp_t : file { open }"
        rlSESearchRule "allow pcp_pmie_t proc_t : file { getattr open read }"
        rlSESearchRule "allow pcp_pmie_t shell_exec_t : file { getattr open read execute }"
        if rlIsRHEL 6 ; then
            rlSESearchRule "allow pcp_pmlogger_t commplex_port_t : tcp_socket { name_bind }"
        else
            rlSESearchRule "allow pcp_pmcd_t unreserved_port_t : tcp_socket { name_bind name_connect }"
            rlSESearchRule "allow pcp_pmlogger_t commplex_link_port_t : tcp_socket { name_bind }"
            rlSESearchRule "allow pcp_pmlogger_t ephemeral_port_t : tcp_socket { name_connect }"
        fi
        rlSESearchRule "allow pcp_pmlogger_t pcp_var_run_t : sock_file { write }"
        rlSESearchRule "type_transition pcp_pmcd_t tmp_t : dir pcp_tmp_t"
        rlSESearchRule "type_transition pcp_pmcd_t tmp_t : file pcp_tmp_t"
        rlSESearchRule "type_transition pcp_pmcd_t tmp_t : sock_file pcp_tmp_t"
    rlPhaseEnd

    rlPhaseStartTest "bz#1286234"
        rlSEMatchPathCon "/usr/bin/pmlogger" "pcp_pmlogger_exec_t"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/pcp/pmlogger.primary.socket" "pcp_var_run_t"
        rlSESearchRule "allow pcp_pmlogger_t var_run_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition pcp_pmlogger_t var_run_t : lnk_file pcp_var_run_t [ ]"
        rlSESearchRule "allow pcp_pmlogger_t pcp_var_run_t : lnk_file { create } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 ; then
        rlPhaseStartTest "bz#1130606"
            rlSESearchRule "allow pcp_pmproxy_t avahi_t : dbus { send_msg }"
            rlSESearchRule "allow avahi_t pcp_pmproxy_t : dbus { send_msg }"
        rlPhaseEnd

        if rlIsRHEL "<8.2"; then
            rlPhaseStartTest "bz#1203153"
                rlSESearchRule "allow pcp_pmwebd_t avahi_t : dbus { send_msg }"
                rlSESearchRule "allow avahi_t pcp_pmwebd_t : dbus { send_msg }"
            rlPhaseEnd
        fi
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1167825"
        if rlIsRHEL "<8.2" ; then
            rlSEMatchPathCon "/usr/libexec/pcp/bin/pmwebd" "pcp_pmwebd_exec_t"
        fi
        rlSEMatchPathCon "/var/lib/sss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/mc" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/mc/passwd" "sssd_public_t"
        rlSEMatchPathCon "/var/lib/sss/pipes" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/run/dbus" "system_dbusd_var_run_t"
        if rlIsRHEL "<8.2" ; then
            rlSESearchRule "allow pcp_pmwebd_t sssd_var_lib_t : dir { search }"
            rlSESearchRule "allow pcp_pmwebd_t sssd_var_lib_t : sock_file { write }"
            rlSESearchRule "allow pcp_pmwebd_t sssd_t : unix_stream_socket { connectto }"
            rlSESearchRule "allow pcp_pmwebd_t sssd_public_t : dir { search }"
            rlSESearchRule "allow pcp_pmwebd_t sssd_public_t : file { getattr open read }"
            rlSESearchRule "allow pcp_pmwebd_t system_dbusd_var_run_t : dir { search }"
            rlSESearchRule "allow pcp_pmwebd_t system_dbusd_var_run_t : sock_file { write }"
            rlSESearchRule "allow pcp_pmwebd_t system_dbusd_t : unix_stream_socket { connectto }"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#1252341"
        rlSEMatchPathCon "/usr/libexec/pcp/bin/pmcd" "pcp_pmcd_exec_t"
        rlSEMatchPathCon "/usr/libexec/pcp/bin/pmlogger" "pcp_pmlogger_exec_t"
        rlSEMatchPathCon "/var/lib/pcp/tmp/pmlogger/primary" "pcp_var_lib_t"
        rlSESearchRule "allow pcp_pmcd_t pcp_var_lib_t : lnk_file { getattr read }"
        rlSESearchRule "allow pcp_pmlogger_t pcp_var_lib_t : lnk_file { create unlink }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1196926 + bz#1213709"
        rlSEMatchPathCon "/usr/libexec/pcp/bin/pmcd" "pcp_pmcd_exec_t"
        rlSEMatchPathCon "/var/lib/pcp/tmp/pmcd" "pcp_var_lib_t"
        rlSEMatchPathCon "/var/lib/pcp/tmp/pmcd/root.socket" "pcp_var_lib_t"
        rlSESearchRule "allow pcp_pmcd_t pcp_var_lib_t : dir { read write add_name remove_name getattr open search }"
        rlSESearchRule "allow pcp_pmcd_t pcp_var_lib_t : sock_file { getattr write create unlink }"
        rlSESearchRule "allow pcp_pmcd_t pcp_pmcd_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1261811 + bz#1309454"
        if rlIsRHEL 7 ; then
            rlSEMatchPathCon "/usr/libexec/pcp/bin/pmcd" "pcp_pmcd_exec_t"
            rlSEMatchPathCon "/var/lib/docker" "docker_var_lib_t"
            rlSEMatchPathCon "/var/lib/docker/containers" "docker_var_lib_t"
            rlSEMatchPathCon "/var/lib/docker/containers/*/config.json" "docker_var_lib_t"
            rlSESearchRule "allow pcp_pmcd_t docker_var_lib_t : dir { ioctl read write getattr lock add_name remove_name search open }"
            rlSESearchRule "allow pcp_pmcd_t docker_var_lib_t : file { ioctl read write create getattr setattr lock append unlink link rename open }"
            rlSESearchRule "allow pcp_pmcd_t docker_var_lib_t : lnk_file { ioctl read write create getattr setattr lock append unlink link rename }"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#1271998"
        if rlIsRHEL 7 ; then
            rlSEMatchPathCon "/etc/mail" "etc_mail_t"
            rlSEMatchPathCon "/etc/mail/sendmail.cf" "etc_mail_t"
            rlSEMatchPathCon "/var/run/rpcbind.sock" "rpcbind_var_run_t"
            rlSEMatchPathCon "/bin/hostname" "hostname_exec_t"
            rlSEMatchPathCon "/usr/bin/pmie" "pcp_pmie_exec_t"
            rlSEMatchPathCon "/var/lib/rpm/Packages" "rpm_var_lib_t"
            rlSEMatchPathCon "/var/log/mail" "sendmail_log_t"
            rlSEMatchPathCon "/usr/lib/systemd/system/pmie.service" "systemd_unit_file_t"
            rlSEMatchPortCon tcp 44321 ephemeral_port_t
            rlSEMatchPortCon tcp 80 http_port_t
            rlSESearchRule "allow pcp_pmcd_t debugfs_t : dir { read }"
            rlSESearchRule "allow pcp_pmcd_t debugfs_t : file { read ioctl open getattr }"
            rlSESearchRule "allow pcp_pmcd_t ephemeral_port_t : tcp_socket { name_connect }"
            # rlSESearchRule "allow pcp_pmcd_t etc_mail_t : dir { search }"
            # rlSESearchRule "allow pcp_pmcd_t etc_mail_t : file { read getattr open }"
            # rlSESearchRule "allow pcp_pmcd_t hostname_exec_t : file { read getattr open execute execute_no_trans }"
            rlSESearchRule "allow pcp_pmcd_t http_port_t : tcp_socket { name_connect }"
            rlSESearchRule "allow pcp_pmcd_t pcp_pmie_exec_t : file { read open execute execute_no_trans }"
            # rlSESearchRule "allow pcp_pmcd_t pcp_tmp_t : file { execute execute_no_trans }"
            rlSESearchRule "allow pcp_pmcd_t rpcbind_t : unix_stream_socket { connectto }"
            rlSESearchRule "allow pcp_pmcd_t rpcbind_var_run_t : sock_file { write }"
            # rlSESearchRule "dontaudit pcp_pmcd_t rpm_var_lib_t : file { open }"
            rlSESearchRule "allow pcp_pmcd_t pcp_pmcd_t : unix_stream_socket { connectto }"
            # rlSESearchRule "allow pcp_pmcd_t sendmail_log_t : dir { search }"
            # rlSESearchRule "allow pcp_pmcd_t unreserved_port_t : tcp_socket { name_bind name_connect }"
            # rlSESearchRule "allow pcp_pmcd_t user_tmp_t : fifo_file { read getattr open }"
            # rlSESearchRule "allow pcp_pmcd_t user_tmp_t : file { execute execute_no_trans }"
            rlSESearchRule "allow pcp_pmie_t systemd_unit_file_t : file { getattr }"
            rlSESearchRule "allow pcp_pmie_t systemd_systemctl_exec_t : file { getattr open read execute_no_trans }"
            rlSESearchRule "type_transition pcp_pmie_t systemd_systemctl_exec_t : process systemd_systemctl_t" 1
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#1211520"
        rlSEMatchPathCon "/var/lib/mysql/mysql.sock" "mysqld_var_run_t"
        rlSESearchRule "allow pcp_pmcd_t mysqld_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow pcp_pmcd_t mysqld_var_run_t : sock_file { write }"
        rlSESearchRule "allow pcp_pmcd_t mysqld_db_t : dir { search }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1309883"
        rlSEMatchPathCon "/usr/sbin/dmsetup" "lvm_exec_t"
        rlSESearchRule "type_transition pcp_pmcd_t lvm_exec_t : process lvm_t [ ]"
        rlSESearchRule "allow pcp_pmcd_t lvm_exec_t : file { read getattr execute open }"
        rlSESearchRule "allow pcp_pmcd_t lvm_t : process transition"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1213740"
        rlSEMatchPathCon "/etc/postfix/main.cf" "postfix_etc_t"
        rlSEMatchPathCon "/var/log/maillog" "var_log_t"
        rlSEMatchPathCon "/var/spool/postfix/incoming" "postfix_spool_t"
        rlSEMatchPathCon "/var/spool/postfix/maildrop" "postfix_spool_maildrop_t"
        rlSESearchRule "allow pcp_pmcd_t postfix_etc_t : file { getattr open read }"
        rlSESearchRule "allow pcp_pmcd_t postfix_spool_maildrop_t : dir { getattr }"
        rlSESearchRule "allow pcp_pmcd_t postfix_spool_t : dir { search getattr }"
        rlSESearchRule "allow pcp_pmcd_t var_log_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1206525"
        rlSEMatchPathCon "/usr/share/pcp/lib/pmie" "pcp_pmie_exec_t"
        rlSEMatchPathCon "/usr/share/pcp/lib/pmlogger" "pcp_pmlogger_exec_t"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1770123"
        rlSEMatchPathCon "/usr/libexec/pcp/bin/pmsignal" "bin_t"
        rlSESearchRule "allow pcp_pmie_t pcp_pmcd_t : process { signal } [ ]"
    rlPhaseEnd
    fi

    if rlIsRHEL '>=7'; then
    rlPhaseStartTest "real scenario -- bz#1309883"
        rlRun "cd /var/lib/pcp/pmdas/dm"
        rlRun "expect -c 'spawn ./Install; expect \"Please\"; send -- \"b\\r\"; expect eof'"

        rlRun "rlServiceStop pmcd pmlogger"
        rlRun "rlServiceStart pmcd pmlogger"

        sleep 5

        rlRun "./Remove"

        rlSECheckAVC --ignore "type=USER_AVC.*status.*pmlogger_t.*init_t.*tclass=system"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- bz#1379371"
        rlRun "rlServiceStart pmcd pmlogger"
        sleep 5
        rlRun "rlServiceStop pmlogger"
        sleep 5
        rlRun "rlServiceStart pmlogger"
        
        sleep 5
        rlSECheckAVC
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone services"
        rlRun "semodule -l | grep pcp"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        for SERVICE_NAME in pmcd pmie pmlogger pmproxy ; do
            if rlIsFedora '>=33' || rlIsRHEL ">=8.1" ; then
                rlRun "systemctl enable ${SERVICE_NAME}"
            else
                rlRun "chkconfig ${SERVICE_NAME} on"
            fi
        done
        for TRIPLET in ${TRIPLETSLIST} ; do
            if rlIsFedora '<33' || rlIsRHEL "<8" ; then
                if ! rlSEDefined "${SEDEFINED}" ; then
                    # for RHELs where the SELinux domain does not exist yet
                    PROCESS_CONTEXT="initrc_t"
                else
                   PROCESS_CONTEXT=`echo ${TRIPLET} | cut -d : -f 3`
                fi
            else
                PROCESS_CONTEXT=`echo ${TRIPLET} | cut -d : -f 3`
            fi
            PROCESS_NAME=`echo ${TRIPLET} | cut -d : -f 4`
            SERVICE_NAME=${PROCESS_NAME}
            if ! echo ${SERVICE_NAMES} | grep -q ${SERVICE_NAME} ; then
                continue # some services are not present in RHEL-6
            fi
            rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status restart status" 1
        done
        for TRIPLET in ${TRIPLETSLIST} ; do
            if rlIsFedora '<33' || rlIsRHEL "<8" ; then
                if ! rlSEDefined "${SEDEFINED}" ; then
                    # for RHELs where the SELinux domain does not exist yet
                    PROCESS_CONTEXT="initrc_t"             
                else
                    PROCESS_CONTEXT=`echo ${TRIPLET} | cut -d : -f 3`
                fi
            else
		PROCESS_CONTEXT=`echo ${TRIPLET} | cut -d : -f 3`
            fi
            PROCESS_NAME=`echo ${TRIPLET} | cut -d : -f 4`
            SERVICE_NAME=${PROCESS_NAME}
            if ! echo ${SERVICE_NAMES} | grep -q ${SERVICE_NAME} ; then
                continue # some services are not present in RHEL-6
            fi
            rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop" 1
        done
        for SERVICE_NAME in pmcd pmie pmlogger pmproxy ; do
            if rlIsFedora '>=33' || rlIsRHEL ">=8.1" ; then
                rlRun "systemctl disable ${SERVICE_NAME}"
            else
                rlRun "chkconfig ${SERVICE_NAME} off"
            fi
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAMES}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

