#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/abrt-services
#   Description: SELinux interferes with various ABRT services
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qa | grep abrt | sort"

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    if rlIsFedora ; then
    rlPhaseStartTest "bz#2274709"
        rlSEMatchPathCon "/usr/bin/abrt-dump-journal-core" "abrt_dump_oops_exec_t"
        rlSEMatchPathCon "/run/systemd/userdb/io.systemd.DynamicUser" "systemd_userdbd_runtime_t"
        rlSEMatchPathCon "/run/systemd/userdb/io.systemd.DropIn" "systemd_userdbd_runtime_t"
        rlSEMatchPathCon "/run/systemd/userdb/io.systemd.Home" "systemd_userdbd_runtime_t"
        rlSESearchRule "allow abrt_dump_oops_t systemd_userdbd_runtime_t : sock_file { write } [ ]"
        rlSESearchRule "allow abrt_dump_oops_t systemd_userdbd_t : unix_stream_socket { connectto } [ ]"
        rlSESearchRule "allow abrt_dump_oops_t init_t : unix_stream_socket { connectto } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario -- bz#2274709"
        for SERVICE_NAME in abrtd abrt-journal-core abrt-oops abrt-pstoreoops abrt-upload-watch abrt-vmcore abrt-xorg ; do
            rlRun "service ${SERVICE_NAME} start"
        done
        sleep 60 &
        sleep 10
        rlRun "killall --signal SIGABRT sleep"
        rlRun "restorecon -Rv /var /run -e /var/ARTIFACTS" 0-255
        for SERVICE_NAME in abrtd abrt-journal-core abrt-oops abrt-pstoreoops abrt-upload-watch abrt-vmcore abrt-xorg ; do
            rlRun "service ${SERVICE_NAME} stop"
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

