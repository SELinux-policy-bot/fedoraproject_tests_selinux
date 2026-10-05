#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/nvme-stas-and-similar
#   Description: SELinux interferes with stacd and stafd services
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
FILE_CONTEXT="nvme_stas_exec_t"
SERVICE_PACKAGE="nvme-stas"
PROCESS_CONTEXT="nvme_stas_t"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ${SERVICE_PACKAGE}

        rlServiceStart avahi-daemon
        rlServiceStop stacd stafd

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlSEDefined "${FILE_CONTEXT} ${PROCESS_CONTEXT}" ; then
    rlPhaseStartTest "bz#2111414 + RHEL-1557"
        rlSEMatchPathCon "/usr/sbin/stacd" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/usr/sbin/stafd" "${FILE_CONTEXT}"
        rlSEMatchPathCon "/dev/nvme-fabrics" "fixed_disk_device_t"
        rlSEMatchPathCon "/run/systemd/journal/socket" "syslogd_var_run_t"
        rlSEMatchPathCon "/run/stacd" "nvme_stas_var_run_t"
        rlSEMatchPathCon "/run/stacd/last-known-config.pickle" "nvme_stas_var_run_t"
        rlSEMatchPathCon "/run/stafd" "nvme_stas_var_run_t"
        rlSEMatchPathCon "/run/stafd/last-known-config.pickle" "nvme_stas_var_run_t"
        rlSEMatchPathCon "/run/udev/" "udev_var_run_t"
        rlSEMatchPathCon "/run/udev/rules.d/" "udev_var_run_t"
        rlSEMatchPathCon "/run/udev/rules.d/70-nvmf-autoconnect.rules" "udev_var_run_t"
        rlSEMatchPathCon "/var/cache/stacd" "nvme_stas_cache_t"
        rlSEMatchPathCon "/var/cache/stafd" "nvme_stas_cache_t"
        SOURCE_TYPE="init_t" # systemd runs the process
        rlSESearchRule "allow ${SOURCE_TYPE} ${FILE_CONTEXT} : file { getattr open read execute } $BOOLEANS"
        rlSESearchRule "allow ${SOURCE_TYPE} ${PROCESS_CONTEXT} : process { transition } $BOOLEANS"
        rlSESearchRule "type_transition ${SOURCE_TYPE} ${FILE_CONTEXT} : process ${PROCESS_CONTEXT} $BOOLEANS"
        rlRun "semodule -lfull | grep stas"
        rlSESearchRule "allow avahi_t nvme_stas_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow nvme_stas_t avahi_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow nvme_stas_t fixed_disk_device_t : chr_file { getattr } [ ]"
        rlSESearchRule "allow nvme_stas_t nvme_stas_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow nvme_stas_t syslogd_var_run_t : sock_file { write } [ ]"
        rlSESearchRule "allow nvme_stas_t system_dbusd_t : dbus { acquire_svc send_msg } [ ]"
        rlSESearchRule "allow nvme_stas_t udev_var_run_t : dir { add_name remove_name write } [ ]"
        rlSESearchRule "allow nvme_stas_t udev_var_run_t : file { create getattr ioctl open unlink write } [ ]"
        rlSESearchRule "allow nvme_stas_t nvme_stas_var_run_t : file { getattr ioctl open read write } [ ]"
        rlSESearchRule "allow unconfined_t nvme_stas_t : dbus { send_msg } [ ]"
        rlSESearchRule "allow nvme_stas_t unconfined_t : dbus { send_msg } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- standalone service"
        for CUR_FILE in /usr/lib/systemd/system/stacd.service \
            /usr/lib/systemd/system/stafd.service ; do
            if grep -q '^ExecStart=.*python' ${CUR_FILE} ; then
                rlRun "cp -f ${CUR_FILE} /etc/systemd/system/"
                COPIED_FILE=`echo ${CUR_FILE} | sed 's|/usr/lib|/etc|'`
                rlRun "sed -i 's|^ExecStart=.*python.* /|ExecStart=/|' ${COPIED_FILE}"
                rlRun "sed -i 's|\(\[Service\]\)|\1\nEnvironment=PYTHONNOUSERSITE=1\n|' ${COPIED_FILE}"
                rlRun "systemctl daemon-reload"
                rlRun "grep '^ExecStart=' ${COPIED_FILE}"
            fi
        done
        if ! rlSEDefined ${PROCESS_CONTEXT} ; then
            # for environments where the SELinux domain does not exist yet
            PROCESS_CONTEXT="unconfined_service_t"
        fi
        rlRun "mkdir -p /etc/nvme"
        rlRun "touch /etc/nvme/hostid"
        rlRun "touch /etc/nvme/hostnqn"
        rlSEService - stafd stafd ${PROCESS_CONTEXT} "start status" 1
        rlRun "stafctl status"
        rlRun "stafctl ls"
        rlSEService - stacd stacd ${PROCESS_CONTEXT} "start status" 1
        rlRun "stacctl status"
        rlRun "stacctl ls"
        rlRun "stasadm -v"
        rlRun "stasadm hostid"
        rlRun "stasadm hostnqn"
        rlRun "restorecon -Rv /etc /var /run -e /var/ARTIFACTS" 0-255
        rlSEService - stacd stacd ${PROCESS_CONTEXT} "restart status stop status" 1
        rlSEService - stafd stafd ${PROCESS_CONTEXT} "restart status stop status" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlRun "rm -f /etc/systemd/system/stacd.service"
        rlRun "rm -f /etc/systemd/system/stafd.service"
        rlRun "systemctl daemon-reload"
        rlServiceRestore stacd stafd
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

