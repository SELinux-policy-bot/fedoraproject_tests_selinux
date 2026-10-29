#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/tpm2-abrmd-and-similar
#   Description: SELinux interferes tpm2-abrmd and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
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
#   License along with this program; if not, see
#   <https://www.gnu.org/licenses/>.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
FILE_PATH="/usr/sbin/tpm2-abrmd"
SERVICE_NAME="tpm2-abrmd"
PROCESS_NAME="tpm2-abrmd"
if seinfo -t | grep -q tabrmd ; then
    FILE_CONTEXT="tabrmd_exec_t"
    PROCESS_CONTEXT="tabrmd_t"
else
    FILE_CONTEXT="bin_t"
    PROCESS_CONTEXT="unconfined_service_t"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qf ${FILE_PATH}"

        rlServiceStop ${SERVICE_NAME}

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-247190"
        rlRun "rpm -qa | grep tpm2-abrmd-selinux"
        rlRun "semodule -lfull | grep tabrmd"
        rlRun "rpm -qf /usr/share/selinux/devel/include/contrib/tabrmd.if | grep tpm2-abrmd-selinux"
        rlRun "rpm -qf /usr/share/selinux/devel/include/contrib/tabrmd.if | grep selinux-policy-devel" 1
    rlPhaseEnd

    if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "modprobe tpm_vtpm_proxy"
        rlRun "lsmod | grep tpm"
        rlRun "ls -lZ /dev/vtpmx"
        rlRun "mkdir -p /var/lib/swtpm/tpm0"
        rlRun "chown -R tss:tss /var/lib/swtpm"
        rlRun "swtpm_setup --tpm-state /var/lib/swtpm/tpm0 --tpm2 --create-ek-cert --create-platform-cert"
        rlRun "swtpm chardev --vtpm-proxy --tpm2 --tpmstate dir=/var/lib/swtpm/tpm0 --daemon"
        sleep 2
        rlRun "ls -lZ /dev/tpm*"
        rlRun "tpm2_getrandom --hex 16"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 2
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 2
        rlRun "gdbus introspect --system --dest com.intel.tss2.Tabrmd --object-path /com/intel/tss2/Tabrmd --recurse"
        rlSEService - ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 2
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

