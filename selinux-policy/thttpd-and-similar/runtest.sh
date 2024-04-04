#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/thttpd-and-similar
#   Description: SELinux interferes with thttpd and related programs
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
FILE_PATH="/usr/sbin/thttpd"
FILE_CONTEXT="httpd_exec_t"
SERVICE_PACKAGE="thttpd"
SERVICE_NAME="thttpd"
PROCESS_NAME="thttpd"
PROCESS_CONTEXT="httpd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStop `rlSEListServices 80`
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if ! rlIsRHEL 5 ; then
    rlPhaseStartTest "bz#1069843"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        if rlIsRHEL 6 ; then
            SOURCE_TYPE="initrc_t"
        else # RHEL-7 etc.
            SOURCE_TYPE="init_t" # systemd runs the process
        fi
        rlSEMatchPathCon "/etc/thttpd.conf" "httpd_config_t"
        rlSEMatchPathCon "/var/log/thttpd.log" "httpd_log_t"
        rlSEMatchPathCon "/var/run/thttpd.pid" "httpd_var_run_t"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#1087384 + bz#1111581"
        if rlIsRHEL 6 ; then
            rlSEMatchPathCon "/etc/rc.d/init.d/thttpd" "httpd_initrc_exec_t"
        else # RHEL-7 etc.
            rlSEMatchPathCon "/lib/systemd/system/thttpd.service" "httpd_unit_file_t"
        fi
        rlSEMatchPathCon "/usr/sbin/thttpd" "httpd_exec_t"
        rlSEMatchPathCon "/var/log/thttpd.log" "httpd_log_t"
        rlSESearchRule "allow httpd_t httpd_t : capability { sys_chroot }"
        rlSESearchRule "allow httpd_t httpd_log_t : file { setattr }"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        # because of the fowner capability
        rlRun "setsebool httpd_run_stickshift on"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if rlIsRHEL 5 ; then
            # for RHELs where the SELinux domain does not exist yet
            PROCESS_CONTEXT="initrc_t"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
        rlRun "setsebool httpd_run_stickshift off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore `rlSEListServices 80`
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

