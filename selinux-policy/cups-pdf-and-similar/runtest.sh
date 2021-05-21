#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/cups-pdf-and-similar
#   Description: SELinux interferes with cups-pdf and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
ROOT_PASSWORD="redhat"
FILE_PATH="/usr/lib/cups/backend/cups-pdf"
FILE_CONTEXT="cups_pdf_exec_t"
SERVICE_PACKAGE="cups-pdf"
SERVICE_NAME="cups"
PROCESS_NAME="cups-pdf"
PROCESS_CONTEXT="cups_pdf_t"
ALLOWED_USERS=${ALLOWED_USERS:-"staff_u user_u sysadm_u unconfined_u"}
DENIED_USERS=${DENIED_USERS:-"guest_u xguest_u"}

rlJournalStart
    if rlIsRHEL || rlIsFedora "<32"; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStart ${SERVICE_NAME}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "${FILE_PATH}" "${FILE_CONTEXT}"
        SOURCE_TYPE="cupsd_t"
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
    rlPhaseEnd

    rlPhaseStartTest "bz#560220 + bz#563977"
        rlSESearchRule "allow cups_pdf_t cups_pdf_t : capability { fowner } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#570782"
        rlSESearchRule "allow cups_pdf_t autofs_t : dir { search } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1516282 + bz#1517509"
        rlSEMatchPathCon "/etc/cups" "cupsd_etc_t"
        rlSESearchRule "allow cups_pdf_t cupsd_etc_t : dir { read } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1532043"
        rlSEMatchPathCon "/run/dbus/system_bus_socket" "system_dbusd_var_run_t"
        rlSESearchRule "allow cups_pdf_t system_dbusd_var_run_t : sock_file { write } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1594271"
        rlSESearchRule "allow cups_pdf_t cups_pdf_t : capability { dac_override } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "bz#1700442"
        rlSEMatchPathCon "/var/log" "var_log_t"
        rlSEMatchPathCon "/var/log/cups" "cupsd_log_t"
        rlSEMatchPathCon "/var/log/cups/cups-pdf-cups-pdf_log" "cupsd_log_t"
        rlSESearchRule "allow cups_pdf_t var_log_t : dir { add_name write } [ ]"
        rlSESearchRule "type_transition cups_pdf_t var_log_t : dir cupsd_log_t"
        rlSESearchRule "type_transition cups_pdf_t var_log_t : file cupsd_log_t"
    rlPhaseEnd

    rlPhaseStartTest "bz#1832521"
        rlSESearchRule "allow cups_pdf_t cups_pdf_t : unix_dgram_socket { create connect } [ ]"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- confined users"
        rlSEConfigureSSH

        rlRun "lpadmin -x cups-pdf" 0-255
        rlRun "lpadmin -p cups-pdf -v cups-pdf:/ -E -P /usr/share/cups/model/CUPS-PDF_opt.ppd"
        rlRun "setsebool ssh_sysadm_login on"
        rlRun "setsebool selinuxuser_tcp_server on"
        rlLog "configuration says not to test SELinux users: ${DENIED_USERS}"
        for SELINUX_USER in ${ALLOWED_USERS} ; do
            USER_NAME="user${RANDOM}"
            USER_SECRET="S3kr3t${RANDOM}"
            rlRun "useradd -Z ${SELINUX_USER} ${USER_NAME}"
            rlRun "echo ${USER_SECRET} | passwd --stdin ${USER_NAME}"
            rlRun "restorecon -Rv /home/${USER_NAME}"
            rlRun "./ssh.exp ${USER_NAME} ${USER_SECRET} localhost lpr -P cups-pdf /usr/share/cups/data/testprint"
            sleep 5
            rlRun "find /home/${USER_NAME} -type f | grep testprint-job"
            rlRun "userdel -rfZ ${USER_NAME}"
            sleep 10
        done
        rlRun "setsebool selinuxuser_tcp_server off"
        rlRun "setsebool ssh_sysadm_login off"
        rlRun "lpadmin -x cups-pdf"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
        rlRun "service sshd restart"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

