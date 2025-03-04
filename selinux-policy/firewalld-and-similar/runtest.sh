#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/firewalld-and-similar
#   Description: SELinux interferes with firewalld and related programs
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
SERVICE_PACKAGE="firewalld"
SERVICE_NAME="firewalld"
PROCESS_NAME="firewalld"
PROCESS_CONTEXT="firewalld_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/firewalld/lockdown-whitelist.xml
        rlFileBackup /etc/shadow
        rlFileBackup /run/firewalld

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#907902"
        rlSEMatchPathCon "/usr/sbin/firewalld" "firewalld_exec_t"
        rlSEMatchPathCon "/usr/lib64/python2.7/site.pyc" "lib_t"
        rlSESearchRule "allow firewalld_t lib_t : dir { getattr open read search }"
        rlSESearchRule "allow firewalld_t lib_t : file { getattr open read execute }"
    rlPhaseEnd

    rlPhaseStartTest "bz#989922"
        rlSEMatchPathCon "/usr/sbin/firewalld" "firewalld_exec_t"
        rlSEMatchPathCon "/etc/firewalld/lockdown-whitelist.xml" "firewalld_etc_rw_t"
        rlSESearchRule "allow firewalld_t firewalld_etc_rw_t : lnk_file { getattr read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1067494"
        for USER_TYPE in user_t staff_t unconfined_t ; do
            rlSESearchRule "allow ${USER_TYPE} firewalld_t : dbus { send_msg }"
            rlSESearchRule "allow firewalld_t ${USER_TYPE} : dbus { send_msg }"
        done
    rlPhaseEnd

    if rlSEDefined "puppetagent_t" ; then
    rlPhaseStartTest "bz#1214853"
        rlSESearchRule "allow firewalld_t puppetagent_t : dbus { send_msg }"
        rlSESearchRule "allow puppetagent_t firewalld_t : dbus { send_msg }"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1221326"
        rlSESearchRule "allow firewalld_t openshift_initrc_t : dbus { send_msg }"
        rlSESearchRule "allow openshift_initrc_t firewalld_t : dbus { send_msg }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1243403"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/xtables.lock" "iptables_var_run_t"
        rlSESearchRule "allow iptables_t iptables_var_run_t : file { getattr open read lock } [ ]"
        rlSESearchRule "type_transition iptables_t var_run_t : file iptables_var_run_t [ ]"
        rlSESearchRule "allow iptables_t var_run_t : dir { read write add_name remove_name getattr open search } [ ]"
        rlRun "sesearch -s unconfined_t -t var_run_t -c file -T | grep \"iptables_var_run_t.*xtables.lock\""
    rlPhaseEnd

    rlPhaseStartTest "bz#1284902"
        rlSESearchRule "allow firewalld_t system_cronjob_t : dbus { send_msg }"
        rlSESearchRule "allow system_cronjob_t firewalld_t : dbus { send_msg }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1342235"
        rlSEMatchPathCon "/var/run/firewalld" "firewalld_var_run_t"
        rlSESearchRule "allow iptables_t firewalld_var_run_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1304723 + bz#1346316"
        rlSEMatchPathCon "/usr/sbin/firewalld" "firewalld_exec_t"
        rlSEMatchPathCon "/var/log" "var_log_t"
        rlSEMatchPathCon "/var/log/firewalld" "firewalld_var_log_t"
        rlSEMatchPathCon "/etc/sysconfig/network-scripts" "net_conf_t"
        rlSEMatchPathCon "/etc/sysconfig/network-scripts/ifcfg-enp0s25.NdcLYC" "net_conf_t"
        rlSESearchRule "allow firewalld_t var_log_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition firewalld_t var_log_t : file firewalld_var_log_t [ ]"
        rlSESearchRule "allow firewalld_t firewalld_var_log_t : file { create } [ ]"
        rlSESearchRule "allow firewalld_t net_conf_t : dir { write add_name }"
        rlSESearchRule "allow firewalld_t net_conf_t : file { getattr open read write rename create unlink setattr }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1342587"
        rlSEMatchPathCon "/usr/sbin/firewalld" "firewalld_exec_t"
        rlSEMatchPathCon "/var/run" "var_run_t"
        rlSEMatchPathCon "/var/run/firewalld" "firewalld_var_run_t"
        rlSESearchRule "allow firewalld_t var_run_t : dir { read write add_name remove_name getattr open search } [ ]"
        rlSESearchRule "type_transition firewalld_t var_run_t : dir firewalld_var_run_t [ ]"
        rlSESearchRule "allow firewalld_t firewalld_var_run_t : dir { create } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1304721"
        rlSESearchRule "allow firewalld_t firewalld_etc_rw_t : file { ioctl read write create getattr setattr lock relabelfrom relabelto append unlink link rename open } ;"
    rlPhaseEnd

    rlPhaseStartTest "bz#1418391"
        rlSEMatchPathCon "/usr/sbin/firewalld" "firewalld_exec_t"
        rlSESearchRule "allow firewalld_t modules_object_t : dir { getattr open read search }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1438708"
        rlSEMatchPathCon "/usr/sbin/firewalld" "firewalld_exec_t"
        rlSEMatchPathCon "/root" "admin_home_t"
        rlSESearchRule "dontaudit firewalld_t admin_home_t : dir { write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1375576"
        rlSESearchRule "allow firewalld_t ldconfig_exec_t : file { getattr open read execute_no_trans } [ ]"
        rlSESearchRule "type_transition firewalld_t ldconfig_exec_t : process ldconfig_t" 1
        rlSESearchRule "allow firewalld_t ldconfig_t : process { transition }" 1
    rlPhaseEnd

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1573501 + bz#1593687 + bz#1600903"
        rlSEMatchPathCon "/usr/sbin/nft" "iptables_exec_t"
        rlSESearchRule "allow firewalld_t firewalld_t : netlink_netfilter_socket { create }"
        rlSESearchRule "allow firewalld_t kernel_t : system { module_request } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1759010"
        rlSEMatchPathCon "/root/.cache" "cache_home_t"
        rlSEMatchPathCon "/home/user/.cache" "cache_home_t"
        rlSESearchRule "dontaudit firewalld_t firewalld_t : capability { dac_override }"
        rlSESearchRule "allow firewalld_t cache_home_t : dir { create }" 1
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "remnants from BZ#1574383"
        rlSESearchRule "allow firewalld_t iptables_exec_t : file { map } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 8 && ! rlIsCentOS 5 6 7 8 ; then
    rlPhaseStartTest "bz#1989641"
        rlSESearchRule "allow firewalld_t firewalld_t : capability { setpcap } [ ]"
        rlSESearchRule "allow firewalld_t firewalld_t : process { setcap } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- bz#1304721"
        rlServiceStart "firewalld"
        rlRun "firewall-cmd --add-port 1234/tcp --permanent"
        rlRun "firewall-cmd --remove-port 1234/tcp --permanent"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- DBus service"
        DESTINATION="org.fedoraproject.FirewallD1"
        rlRun "gdbus introspect --system --object-path / --dest ${DESTINATION} >& /dev/null"
        sleep 1
        rlRun "ps -efZ | grep -v grep | grep ${PROCESS_NAME}"
        rlRun "ps -efZ | grep -v grep | grep \"${PROCESS_CONTEXT}.*${PROCESS_NAME}\""
        rlServiceStop "firewalld"
    rlPhaseEnd

    rlPhaseStartTest "real scenario"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        rlRun "rm -rf /run/firewalld"
        rlRun "rm -f /run/xtables.lock"
        if [ -f /etc/firewalld/lockdown-whitelist.xml ] ; then
            rlRun "mv /etc/firewalld/lockdown-whitelist.xml /etc/firewalld/lockdown-whitelist.xml.orig"
            rlRun "ln -s /etc/firewalld/lockdown-whitelist.xml.orig /etc/firewalld/lockdown-whitelist.xml"
        fi
        # see https://bugzilla.redhat.com/show_bug.cgi?id=907902#c7
        # rlRun "rm -f /usr/lib{,64}/python2.7/site.{pyc,pyo}"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
        rlRun "rm -f /etc/firewalld/lockdown-whitelist.xml*"
        rlRun "ls -dZ /run/firewalld | grep :firewalld_var_run_t"
        if rlIsRHEL 7 ; then
            rlRun "ls -Z /run/xtables.lock | grep :iptables_var_run_t"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

