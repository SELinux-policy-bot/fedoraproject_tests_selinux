#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/caddy-and-similar
#   Description: SELinux interferes with caddy services and related programs
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
SERVICE_PACKAGE="caddy"
PROCESS_NAME="caddy"
PROCESS_CONTEXT="httpd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        if ! rpm -q ${SERVICE_PACKAGE} ; then
            rlRun "yum -y install ${SERVICE_PACKAGE} --enablerepo epel"
        fi
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop caddy caddy-api

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1706651"
        rlSEMatchPathCon "/usr/bin/caddy" "httpd_exec_t"
        rlSEMatchPathCon "/var/lib/caddy" "httpd_var_lib_t"
        rlSESearchRule "allow init_t httpd_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition init_t httpd_exec_t : process httpd_t [ ]"
        rlSESearchRule "allow init_t httpd_t : process { transition } [ ]"
        rlSESearchRule "allow init_t httpd_var_lib_t : dir { mounton } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#2122886"
        rlSEMatchPathCon "/usr/bin/caddy" "httpd_exec_t"
        rlRun "ls -Z /proc/sys/net/core/somaxconn | grep :sysctl_net_t"
        rlSESearchRule "allow httpd_t sysctl_net_t : file { getattr open read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "semanage fcontext -l -C | grep caddy"
        for SERVICE_NAME in caddy caddy-api ; do
            rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
            rlRun "restorecon -Rv /run /var" 0-255
            rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore caddy caddy-api
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

