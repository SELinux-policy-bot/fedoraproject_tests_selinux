#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-run-and-similar
#   Description: SELinux interferes with systemd-run and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
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
        rlAssertRpm systemd
        rlRun "setsebool daemons_use_tty on"

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "bz#1559409 + bz#1647162"
        rlSEMatchPathCon "/usr/bin/systemd-run" "bin_t"
        rlSESearchRule "allow init_t user_devpts_t : chr_file { setattr open } [ ]"
    rlPhaseEnd

    if seinfo --common file -x | grep -q watch ; then
    rlPhaseStartTest "bz#1980241"
        rlSESearchRule "allow init_t user_devpts_t : chr_file { watch watch_reads } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartTest "real scenario"
        rlWatchdog "systemd-run -p IPAddressDeny=127.0.0.1 -t /bin/sh" 10
        rlWatchdog "systemd-run --user --pty bash -i" 10
        rlWatchdog "systemd-run --system --pty bash -i" 10
        if systemd-run --help | grep -q -- --shell ; then
            rlWatchdog "systemd-run --shell" 10
        fi
    rlPhaseEnd

    rlPhaseStartTest "bz#2118784"
        rlSEMatchPathCon "/var/lib" "var_lib_t"
        rlSEMatchPathCon "/var/lib/myservice0" "var_lib_t"
        rlSESearchRule "allow init_t var_lib_t : lnk_file { getattr read } [ ]"
        rlRun "systemd-run -p DynamicUser=yes -p StateDirectory=myservice0  touch /var/lib/myservice0/foo"
        rlRun "systemd-run -p DynamicUser=yes -p StateDirectory=myservice0 --pipe wc -c /var/lib/myservice0/foo"
        rlRun "ls -alZ /var/lib/myservice0 /var/lib/private/myservice0"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlRun "setsebool daemons_use_tty off"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

