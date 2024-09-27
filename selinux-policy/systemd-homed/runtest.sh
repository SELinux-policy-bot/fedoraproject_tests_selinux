#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/systemd-homed
#   Description: Test coverage for SELinux AVC issues related to systemd-homed service.
#   Author: Amith Kumar <apeetham@redhat.com>
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

PACKAGE1="selinux-policy"
PACKAGE2="systemd"

function create_u() {
expect -f  - <<<'
    set timeout -1
    spawn homectl create test_u --disk-size=500M
    expect "*: "
    send -- "Red_123hat\r"
    expect "*: "
    send -- "Red_123hat\r"
    expect eof
    foreach {pid spawnid os_error_flag value} [wait] break
    exit $value     
'
}

function activate_u() {
expect -f  - <<<'
   set timeout -1
   spawn homectl activate test_u
   expect "*: "
   send -- "Red_123hat\r"
   expect eof
   foreach {pid spawnid os_error_flag value} [wait] break
   exit $value
'
}

function unlock_u() {
expect -f  - <<<'
   set timeout -1
   spawn homectl unlock test_u
   expect "*: "
   send -- "Red_123hat\r"
   expect eof
   foreach {pid spawnid os_error_flag value} [wait] break
   exit $value
'
}

function passwd_u() {
expect -f  - <<<'
   set timeout -1
   spawn homectl passwd test_u
   expect "*: "
   send -- "Sim_123pl1\r"
   expect "*: "
   send -- "Sim_123pl1\r"
   expect eof
   foreach {pid spawnid os_error_flag value} [wait] break
   exit $value
'
}

function auth_u() {
expect -f  - <<<'
   set timeout -1
   spawn homectl authenticate test_u
   expect "*: "
   send -- "Sim_123pl1\r"
   expect eof
   foreach {pid spawnid os_error_flag value} [wait] break
   exit $value
'
}

function resize_u() {
expect -f  - <<<'
   set timeout -1
   spawn homectl resize test_u 425.0M
   expect "*: "
   send -- "Sim_123pl1\r"
   expect eof
   foreach {pid spawnid os_error_flag value} [wait] break
   exit $value
'
}

rlJournalStart
    if ! seinfo -t systemd_homed_t | grep -q systemd_homed_t ; then
        rlLog "Not applicable to this OS version."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE1}
        rlAssertRpm ${PACKAGE1}-targeted
        rlAssertRpm ${PACKAGE2}
        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
        rlRun "systemctl enable systemd-homed"
    rlPhaseEnd

    rlPhaseStartTest "homectl create"
        rlRun "create_u"
        rlRun "ausearch -m AVC -m USER_AVC -c systemd-homed -f mail --input-logs" 1
        rlRun "ausearch -m AVC -m USER_AVC -c systemd-homewor --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl list"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "homectl list"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl activate"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "activate_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl inspect"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "homectl inspect test_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl update"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "homectl update test_u --email-address=test_u@redhat.com"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl lock"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "homectl lock test_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl unlock"
        sleep 90
        tst_Time="$(date '+%T')"
        rlRun "unlock_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl passwd"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "passwd_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl authenticate"
        sleep 90
        tst_Time="$(date '+%T')"
        rlRun "auth_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl deactivate and resize"
        sleep 90
        tst_Time="$(date '+%T')"
        rlRun "homectl deactivate test_u"
        sleep 60
        rlRun "resize_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "homectl remove"
        sleep 20
        tst_Time="$(date '+%T')"
        rlRun "homectl remove test_u"
        sleep 5
        rlRun "ausearch -m AVC -m USER_AVC --start $tst_Time --input-logs" 1
    rlPhaseEnd

    rlPhaseStartTest "bz#2036108 + bz#2315087"
        rlSEMatchPathCon "/usr/lib/systemd/systemd-homed" "systemd_homed_exec_t"
        rlSEMatchPathCon "/var/cache/systemd/" "systemd_cache_t"
        rlSEMatchPathCon "/var/cache/systemd/home/" "systemd_homed_cache_t"
        rlSESearchRule "allow systemd_homed_t systemd_homed_cache_t : dir { read } [ ]"

        rlRun "service systemd-homed restart"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "systemctl disable systemd-homed"
        sleep 2
        rlSECheckAVC
        rlRun "rm -f /tmp/avcfile"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
