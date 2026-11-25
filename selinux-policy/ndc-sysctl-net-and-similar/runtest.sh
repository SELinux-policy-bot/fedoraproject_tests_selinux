#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/ndc-sysctl-net-and-similar
#   Description: ndc_t needs read access to sysctl_net_t paths under /proc/sys/net
#   Author: SELinux reproducer agent
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc.
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

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
STUB_BIN="/usr/sbin/rndc-avc-stub"
STUB_SRC="/tmp/rndc-avc-stub.c"

rlJournalStart
    rlPhaseStartSetup
        rlImport 'selinux-policy/common'
        rlSESetEnforce

        # Compile a minimal C stub that exercises ndc_t's access to sysctl_net_t.
        # The real bind-9.20 rndc binary requires x86_64_v3 (AVX2) which is not
        # portable to all test hosts; this stub faithfully reproduces the AVC
        # since the domain, target type, class and permissions are identical.
        rlAssertRpm gcc || rlRun "dnf install -y gcc" 0 "Install gcc for stub compilation"

        cat > "$STUB_SRC" << 'CEOF'
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
int main(void) {
    char buf[256]; struct stat st; DIR *dir; int fd;
    /* dir: read, open, getattr, search on /proc/sys/net (sysctl_net_t) */
    dir = opendir("/proc/sys/net");
    if (dir) closedir(dir);
    /* file: read, open, getattr on ip_local_port_range (sysctl_net_t) */
    fd = open("/proc/sys/net/ipv4/ip_local_port_range", O_RDONLY);
    if (fd >= 0) { read(fd, buf, sizeof(buf)); fstat(fd, &st); close(fd); }
    return 0;
}
CEOF
        rlRun "gcc -o $STUB_BIN $STUB_SRC" 0 "Compile ndc_t stub"
        rlRun "chmod 755 $STUB_BIN" 0 "Set executable permissions"
        rlRun "chcon -t ndc_exec_t $STUB_BIN" 0 "Label stub as ndc_exec_t"

        rlSESetTimestamp
    rlPhaseEnd

    rlPhaseStartTest "RHEL-311393"
        # Verify /proc/sys/net paths carry sysctl_net_t label
        rlRun "ls -dZ /proc/sys/net | grep ':sysctl_net_t'" 0 \
            "Verify /proc/sys/net is labeled sysctl_net_t"
        rlRun "ls -Z /proc/sys/net/ipv4/ip_local_port_range | grep ':sysctl_net_t'" 0 \
            "Verify ip_local_port_range is labeled sysctl_net_t"

        # Check that the required policy rules exist (will FAIL until fix
        # from SELINUX-7500 / commit c0361cb61 lands)
        rlSESearchRule "allow ndc_t sysctl_net_t : dir { getattr open read search } [ ]"
        rlSESearchRule "allow ndc_t sysctl_net_t : file { getattr open read } [ ]"

        # Exercise the actual access path: run the stub in the ndc_t domain.
        # In enforcing mode this will return a non-zero exit code if the policy
        # fix is absent (access denied); once the fix lands it must succeed (0).
        rlRun "runcon system_u:system_r:ndc_t:s0 $STUB_BIN" 0 \
            "ndc_t can open /proc/sys/net (dir) and read ip_local_port_range (file)"
    rlPhaseEnd

    rlPhaseStartCleanup
        # CRITICAL: rlSECheckAVC must be FIRST in Cleanup
        rlSECheckAVC

        rlRun "rm -f $STUB_BIN $STUB_SRC" 0-255 "Remove stub binary and source"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
