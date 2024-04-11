#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/bz733494-amanda-and-similar
#   Description: SELinux interferes with amanda and related tools
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/lib/amanda/amandad"
FILE_CONTEXT="amanda_inetd_exec_t"
SERVICE_NAME="amanda"
PROCESS_NAME="amandad"
PROCESS_CONTEXT="amanda_t"

rlJournalStart
    if rlIsRHEL && ! rlIsRHEL 7 8 ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm amanda
        rlAssertRpm amanda-client
        rlAssertRpm amanda-server

        if rlIsRHEL 5 6 ; then
            rlServiceStop xinetd
        fi
        rlFileBackup /etc/shadow
        rlFileBackup /etc/krb5.conf
        rlFileBackup /etc/krb5.keytab

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#283971"
        # META-Fixed-In: selinux-policy-2.4.6-91.el5
        if ! rlIsRHEL 5 ; then
            rlSEMatchPathCon "/usr/sbin/amandad" "bin_t"
        fi
        rlSEMatchPathCon "/usr/lib/amanda/amandad" "amanda_inetd_exec_t"
        rlSEMatchPortCon "tcp" "389" "ldap_port_t"
        if ! rlIsRHEL 7 ; then
            rlSESearchRule "allow amanda_t ldap_port_t : tcp_socket { name_connect }"
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#498596"
        # META-Fixed-In: selinux-policy-2.4.6-230.el5
        rlSEMatchPathCon "/usr/lib/amanda/killpgrp" "amanda_exec_t"
        rlSESearchRule "allow amanda_t fsadm_t : process { signal }"
    rlPhaseEnd

    if rlIsRHEL 6 ; then
    rlPhaseStartTest "bz#729361"
        rlSEMatchPathCon "/bin/mailx" "sendmail_exec_t"
        rlSEMatchPathCon "/var/lib/amanda/Data/amdump" "amanda_data_t"
        rlSEMatchPathCon "/var/lib/amanda/Data/log" "amanda_log_t"
        rlSESearchRule "allow sendmail_t amanda_var_lib_t : file { getattr open append }"
        # FIXME: based on known AVCs there is a problem with initrc_tmp_t file
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#733494"
        # META-Fixed-In: selinux-policy-3.7.19-109.el6
        rlSESearchRule "allow amanda_t amanda_t : process { setsched }"
        rlSESearchRule "allow amanda_t amanda_data_t : lnk_file { create unlink }"
        rlSESearchRule "allow amanda_t amanda_data_t : dir { add_name remove_name create rmdir write }"
        # FIXME: dontaudit rules for getattr operations on directories in /proc are missing
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1371561"
		rlSEMatchPathCon "/var/lib" "var_lib_t"
		rlSEMatchPathCon "/var/lib/amanda" "amanda_var_lib_t"
        rlSESearchRule "allow amanda_t var_lib_t : dir { add_name write }"
        rlSESearchRule "allow amanda_t amanda_t : capability { sys_admin }"
        rlSESearchRule "type_transition amanda_t var_lib_t : dir amanda_var_lib_t"
        rlSESearchRule "allow amanda_t amanda_var_lib_t : dir { create setattr }"
        rlSESearchRule "allow amanda_t amanda_var_lib_t : file { create setattr write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1452444"
        rlSEMatchPathCon "/usr/lib64/amanda/amandad" "amanda_inetd_exec_t"
        rlSEMatchPathCon "/dev/shm" "tmpfs_t"
        rlSESearchRule "type_transition amanda_t tmpfs_t : dir amanda_tmpfs_t"
        rlSESearchRule "type_transition amanda_t tmpfs_t : file amanda_tmpfs_t"
        rlSESearchRule "allow amanda_t tmpfs_t : filesystem { getattr }"
        rlSESearchRule "allow amanda_t tmpfs_t : dir { read write add_name remove_name }"
        rlSESearchRule "allow amanda_t amanda_tmpfs_t : dir { getattr open read write search add_name remove_name }"
        rlSESearchRule "allow amanda_t amanda_tmpfs_t : file { getattr open read write create link unlink }"
        rlSESearchRule "allow amanda_t amanda_t : capability { setgid }"
        rlSESearchRule "allow amanda_t proc_net_t : file { getattr open read }"
    rlPhaseEnd
    fi

    if false ; then
    rlPhaseStartTest "bz#1623052"
        rlSEMatchPathCon "/usr/lib64/amanda/amandad" "amanda_inetd_exec_t"
        rlSEMatchPathCon "/var/tmp/host_0" "krb5_host_rcache_t"
        rlSESearchRule "allow amanda_t krb5_host_rcache_t : file { write unlink } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#965140"
        if rlIsRHEL 5 ; then
            SOURCE_TYPE="inetd_t" # xinetd runs the process
            BOOLEANS="[ amanda_disable_trans ]"
        elif rlIsRHEL 6 ; then
            SOURCE_TYPE="inetd_t" # xinetd runs the process
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/usr/sbin/prelink" "prelink_exec_t"
        rlSEMatchPathCon "/usr/lib/amanda/*" "amanda_exec_t"
        rlSEMatchPathCon "/usr/lib64/amanda/*" "amanda_exec_t"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } ${BOOLEANS}"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} ${BOOLEANS}"
        rlSESearchRule "allow prelink_t amanda_exec_t : file { getattr }"
        rlSESearchRule "allow setroubleshootd_t amanda_exec_t : file { getattr }"
        rlSESearchRule "allow unconfined_t amanda_exec_t : file { getattr }"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1630963"
        rlSESearchRule "allow amanda_t amanda_tmpfs_t : file { map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1739137"
        # xfsdump is executed from amanda_t and stays in amanda_t
        rlSEMatchPathCon "/usr/sbin/xfsdump" "bin_t"
        rlSEMatchPathCon "/dev/random" "random_device_t"
        rlSEMatchPathCon "/var/lib/xfsdump" "var_lib_t"
        rlSEMatchPathCon "/var/lib/xfsdump/inventory" "amanda_var_lib_t"
        rlSEMatchPathCon "/var/lib/xfsdump/inventory/1fa2bf89-02c1-4bba-bc3d-a265cbd5eff2.InvIndex" "amanda_var_lib_t"
        rlSESearchRule "allow amanda_t random_device_t : chr_file { getattr open read } [ ]"
        rlSESearchRule "allow amanda_t amanda_var_lib_t : file { create write setattr } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 8 && ! rlIsCentOS 5 6 7 8 ; then
    rlPhaseStartTest "bz#1960513"
        rlRun "ls -l /usr/sbin/amandad"
        rlSEMatchPathCon "/usr/lib64/amanda/amandad" "amanda_inetd_exec_t"
        rlSEMatchPathCon "/sys/fs/cgroup" "cgroup_t"
        rlSESearchRule "allow amanda_t cgroup_t : filesystem { getattr } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "real scenario -- amanda-udp"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for RHELs where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlRun "systemctl enable amanda-udp.socket"
        rlRun "systemctl start amanda-udp.socket"
        rlSEService ${ROOT_PASSWORD} amanda-udp amandad amanda_t "start status" 1
        rlRun "restorecon -Rv /run /var -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} amanda-udp amandad amanda_t "restart status stop status" 1
        rlRun "systemctl stop amanda-udp.socket"
        rlRun "systemctl disable amanda-udp.socket"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- kamanda"
        rlRun "rm -f /etc/krb5.conf /etc/krb5.keytab"
        FQDN=`hostname -f`
        rlRun 'echo -en "read_kt krb5.keytab\nclear\nadd_entry -password -p host/${FQDN}@EXAMPLE.COM -k 2 -e aes128-cts-hmac-sha1-96\nblahblah\nwrite_kt krb5.keytab\nl\nq\n" | ktutil'
        rlRun "cp krb5.conf krb5.keytab /etc"
        rlRun "restorecon -Rv /etc"
        PORT_NUMBER="10082"
        HOST_ADDRESS="127.0.0.1"
        rlRun "systemctl enable kamanda.socket"
        rlRun "systemctl start kamanda.socket"
        rlLog "starting provocateur job"
        ( tail -f - | ncat ${HOST_ADDRESS} ${PORT_NUMBER} ) &
        PROVOCATEUR_PID=$!
        sleep 1
        rlRun "netstat -tupan | grep :${PORT_NUMBER}"
        rlRun "ps -o pid,user,context,args -C ${PROCESS_NAME}"
        rlRun "ps -o pid,user,context,args -C ${PROCESS_NAME} | grep :${PROCESS_CONTEXT}"
        rlRun "kill ${PROVOCATEUR_PID}"
        rlRun "killall ncat" 0,1
        rlRun "systemctl stop kamanda.socket"
        rlRun "systemctl disable kamanda.socket"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- xinetd service"
        HOST_ADDRESS="127.0.0.1"
        PORT_NUMBER="10080" # number or socket path
        if rlIsRHEL 5 6 ; then
            PORT_TYPE="-u" # default is TCP, otherwise use -u (UDP) or --sctp (SCTP)
            rlRun "chkconfig ${SERVICE_NAME} on"
            rlRun "service xinetd restart"
            rlLog "starting provocateur job"
            ( echo | nc ${PORT_TYPE} ${HOST_ADDRESS} ${PORT_NUMBER} ) &
            PROVOCATEUR_PID=$!
        else
            PORT_TYPE="" # default is TCP, otherwise use -u (UDP) or --sctp (SCTP)
            rlRun "systemctl enable ${SERVICE_NAME}.socket"
            rlRun "systemctl start ${SERVICE_NAME}.socket"
            rlLog "starting provocateur job"
            ( tail -f - | ncat ${PORT_TYPE} ${HOST_ADDRESS} ${PORT_NUMBER} ) &
            PROVOCATEUR_PID=$!
        fi
        sleep 1
        rlRun "netstat -tupan | grep :${PORT_NUMBER}"
        rlRun "ps -o pid,user,context,args -C ${PROCESS_NAME}"
        rlRun "ps -o pid,user,context,args -C ${PROCESS_NAME} | grep :${PROCESS_CONTEXT}"
        rlRun "kill ${PROVOCATEUR_PID}"
        rlRun "killall ncat" 0,1
        if rlIsRHEL 5 6 ; then
            rlRun "chkconfig ${SERVICE_NAME} off"
            rlRun "service xinetd stop"
        else
            rlRun "systemctl stop ${SERVICE_NAME}.socket"
            rlRun "systemctl disable ${SERVICE_NAME}.socket"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        if rlIsRHEL 5 6 ; then
            rlServiceRestore xinetd
        fi
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd

