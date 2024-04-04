#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/kerberos-and-similar
#   Description: SELinux interferes with kerberos programs
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

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm krb5-libs
        rlAssertRpm krb5-server

        rlServiceStop kprop kadmin
        rlFileBackup /etc/shadow
        rlFileBackup /etc/krb5.conf

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#698923"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSESearchRule "allow kadmind_t kadmind_t : process { getsched setsched }"
    rlPhaseEnd

    rlPhaseStartTest "bz#713218"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/var/run/ldapi" "slapd_var_run_t"
        rlSESearchRule "allow kadmind_t slapd_var_run_t : sock_file { write }"
        rlSESearchRule "allow kadmind_t slapd_t : unix_stream_socket { connectto }"
    rlPhaseEnd

    rlPhaseStartTest "bz#860666"
        rlSEMatchPathCon "/usr/sbin/krb5kdc" "krb5kdc_exec_t"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#910837"
        rlSEMatchPathCon "/usr/sbin/krb5kdc" "krb5kdc_exec_t"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/etc/passwd" "passwd_file_t"
        rlSESearchRule "allow kadmind_t passwd_file_t : file { getattr open read }"
        rlSESearchRule "allow krb5kdc_t passwd_file_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1041629"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/pac" "sssd_var_lib_t"
        rlSESearchRule "allow kadmind_t sssd_var_lib_t : sock_file { write }"
        rlSESearchRule "allow kadmind_t sssd_t : unix_stream_socket { connectto }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1065460"
        rlSEMatchPathCon "/usr/sbin/krb5kdc" "krb5kdc_exec_t"
        rlSEMatchPathCon "/var/run/krb5kdc" "krb5kdc_var_run_t"
        rlSEMatchPathCon "/var/run/krb5kdc/DEFAULT.socket" "krb5kdc_var_run_t"
        rlSESearchRule "allow krb5kdc_t krb5kdc_var_run_t : sock_file { write }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1153561"
        rlSEMatchPathCon "/usr/sbin/_kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/usr/sbin/_kpropd" "kpropd_exec_t"
        rlRun "ls -Z /proc/meminfo | grep :proc_t"
        rlSEMatchPathCon "/etc/passwd" "passwd_file_t"
        rlSESearchRule "allow kpropd_t proc_t : file { getattr open read }"
        rlSESearchRule "allow kpropd_t passwd_file_t : file { getattr open read }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1319933"
        rlSEMatchPathCon "/usr/sbin/krb5kdc" "krb5kdc_exec_t"
        rlSEMatchPathCon "/var/lib/sss/pipes" "sssd_var_lib_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/pac" "sssd_var_lib_t"
        rlSESearchRule "allow krb5kdc_t sssd_var_lib_t : dir { getattr search open }"
        rlSESearchRule "allow krb5kdc_t sssd_var_lib_t : sock_file { write }"
        rlSESearchRule "allow krb5kdc_t sssd_t : unix_stream_socket { connectto }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1452215"
        rlSEMatchPathCon "/var/kerberos/krb5kdc/cacert.pem" "krb5kdc_conf_t"
        rlSESearchRule "allow httpd_t krb5kdc_conf_t : file { getattr open read }"
    rlPhaseEnd
    fi

    rlPhaseStartTest "bz#1210421 + bz#1220691 + bz#1220763"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/usr/sbin/kpropd" "kpropd_exec_t"
        rlSEMatchPathCon "/var/tmp" "tmp_t"
        rlSEMatchPathCon "/var/tmp/kadmin_0" "kadmind_tmp_t"
        rlSEMatchPathCon "/var/tmp/kiprop_0" "kadmind_tmp_t"
        rlSEMatchPathCon "/etc/krb5.keytab" "krb5_keytab_t"
        rlSEMatchPortCon tcp 754 kprop_port_t
        rlSESearchRule "type_transition kadmind_t tmp_t : file kadmind_tmp_t"
        rlSESearchRule "allow kadmind_t kadmind_tmp_t : file { create write open unlink }"
        rlSESearchRule "allow kpropd_t kprop_port_t : tcp_socket { name_connect }"
        rlSESearchRule "allow kadmind_t kprop_port_t : tcp_socket { name_bind }"
        rlSESearchRule "allow kadmind_t krb5_keytab_t : file { getattr open read lock }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1337895"
        rlSEMatchPathCon "/usr/sbin/kpropd" "kpropd_exec_t"
        rlSEMatchPathCon "/var/lib/sss/pipes/nss" "sssd_var_lib_t"
        rlSESearchRule "allow kpropd_t sssd_var_lib_t : sock_file { write }"
        rlSESearchRule "allow kpropd_t sssd_t : unix_stream_socket { connectto }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1368492"
        rlSEMatchPathCon "/usr/sbin/krb5kdc" "krb5kdc_exec_t"
        rlSEMatchPathCon "/var/kerberos/krb5kdc/kdc.conf.d" "krb5kdc_conf_t"
        rlSESearchRule "allow krb5kdc_t krb5kdc_conf_t : dir { getattr open read search }"
        rlSESearchRule "allow gssd_t krb5_conf_t : dir { getattr open read search }"
        if ! rlIsRHEL 5 6 ; then
            rlSESearchRule "allow gssproxy_t krb5_conf_t : dir { getattr open read search }"
        fi
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1600705"
        rlSEMatchPathCon "/usr/sbin/kpropd" "kpropd_exec_t"
        rlSEMatchPathCon "/usr/sbin/_kpropd" "kpropd_exec_t"
        rlSESearchRule "allow kpropd_t kpropd_exec_t : file { execute_no_trans } [ ]"
        rlSESearchRule "allow kpropd_t proc_net_t : file { getattr open read } [ ]"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "bz#1601004"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/var/kerberos/krb5kdc/principal.ulog" "krb5kdc_principal_t"
        rlSESearchRule "allow kadmind_t krb5kdc_principal_t : file { map }"
    rlPhaseEnd

    rlPhaseStartTest "bz#1619252"
        rlSEMatchPathCon "/usr/sbin/kpropd" "kpropd_exec_t"
        rlSEMatchPathCon "/var/kerberos/krb5kdc/principal.ulog" "krb5kdc_principal_t"
        rlSESearchRule "allow kadmind_t krb5kdc_principal_t : file { map }"
    rlPhaseEnd
    fi

    if ! rlIsRHEL 5 6 7 ; then
    rlPhaseStartTest "bz#1664983"
        rlSEMatchPathCon "/usr/sbin/kadmind" "kadmind_exec_t"
        rlSEMatchPathCon "/root/.config" "config_home_t"
        rlSEMatchPathCon "/root/.config/pkcs11" "config_home_t"
        rlSEMatchPathCon "/root/.config/pkcs11/pkcs11.conf" "config_home_t"
        rlSEMatchPathCon "/root/.config/pkcs11/modules" "config_home_t"
        rlSEMatchPathCon "/root/.config/softhsm2" "config_home_t"
        rlSEMatchPathCon "/root/.config/softhsm2/softhsm2.conf" "config_home_t"
        rlSEMatchPathCon "/var/lib/softhsm/tokens" "named_cache_t"
        rlSEMatchPathCon "/etc/pkcs11" "etc_t"
        rlSEMatchPathCon "/etc/pkcs11/modules" "pkcs11_modules_conf_t"
        rlSEMatchPathCon "/etc/pkcs11/modules/softhsm2.module" "pkcs11_modules_conf_t"
        rlSESearchRule "allow kadmind_t config_home_t : dir { search } [ ]"
        rlSESearchRule "allow kadmind_t named_cache_t : dir { search } [ ]"
        rlSESearchRule "allow kadmind_t pkcs11_modules_conf_t : dir { getattr open read search } [ ]"
        rlSESearchRule "allow kadmind_t pkcs11_modules_conf_t : file { getattr map open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1669975"
        # TODO: identify processes which need to access following locations
        rlSEMatchPathCon "/var/kerberos/krb5/user" "krb5_keytab_t"
        rlSEMatchPathCon "/var/kerberos/krb5/user/1234" "krb5_keytab_t"
        rlSEMatchPathCon "/var/kerberos/krb5/user/1234/client.keytab" "krb5_keytab_t"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario for kpropd"
        rlRun "touch /var/kerberos/krb5kdc/kpropd.acl"
        rlRun "rm -f /etc/krb5.conf"
        rlRun "cp ./krb5.conf /etc"
        rlRun "restorecon -v /etc/krb5.conf"
        rlSEService ${ROOT_PASSWORD} kprop kpropd kpropd_t "start status restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore kprop kadmin
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

