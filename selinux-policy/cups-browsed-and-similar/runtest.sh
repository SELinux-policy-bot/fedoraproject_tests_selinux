#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/cups-browsed-and-similar
#   Description: SELinux interferes with cups-browsed and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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
FILE_PATH="/usr/sbin/cups-browsed"
FILE_CONTEXT="cupsd_exec_t"
SERVICE_NAME="cups-browsed"
PROCESS_NAME="cups-browsed"
PROCESS_CONTEXT="cupsd_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        SERVICE_PACKAGE=`rpm -qf ${FILE_PATH} | head -n 1`
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlFileBackup /etc/shadow
        rlFileBackup /etc/cups/cups-browsed.conf
        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        rlSESearchRule "allow initrc_t ${FILE_CONTEXT} : file { getattr open read execute }"
        rlSESearchRule "allow initrc_t ${PROCESS_CONTEXT} : process { transition }"
        rlSESearchRule "type_transition initrc_t ${FILE_CONTEXT} : process ${PROCESS_CONTEXT}"
    rlPhaseEnd

    rlPhaseStartTest "bz#1395801 + bz#1401634 + bz#1719754"
        rlSEMatchPathCon "/usr/sbin/cups-browsed" "cupsd_exec_t"
        rlSEMatchPathCon "/tmp" "tmp_t"
        rlSESearchRule "allow cupsd_t tmp_t : dir { write add_name } [ ]"
        rlSESearchRule "type_transition cupsd_t tmp_t : lnk_file cupsd_tmp_t"
        rlSESearchRule "allow cupsd_t cupsd_tmp_t : lnk_file { create unlink } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario"
        rlRun "echo -en '\nBrowsePoll localhost\n' >> /etc/cups/cups-browsed.conf"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            if rlIsRHEL 5 6 ; then
                PROCESS_CONTEXT="initrc_t"
            else
                PROCESS_CONTEXT="unconfined_service_t"
            fi
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        if ! rlIsRHEL 9 && ! rlIsCentOS 9 ; then
            # RHEL-47401 closed as won't fix
            # RHEL-54579 will be fixed in RHEL-10
            rlRun "mkdir -p /root/.cups"
            rlRun "touch /root/.cups/lpoptions"
        fi
        rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        # Ignore specific avc denial on rhel-9 due to RHEL-47401
        if rlIsRHEL 9 || rlIsCentOS 9; then
            rlSECheckAVC --ignore 'type=AVC.*comm=cups-browsed.*name=lpoptions.*scontext=.*:cupsd_t:.*tcontext=.*:admin_home_t:.*tclass=file'
        else
            rlSECheckAVC
        fi

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
        rlServiceStop cups
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

