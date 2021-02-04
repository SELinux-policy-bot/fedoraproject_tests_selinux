#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/policycoreutils/Sanity/setfiles
#   Description: Basic sanity tests for setfiles
#   Author: Michal Trunecka <mtruneck@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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

PACKAGE="policycoreutils"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        OUTPUT=`mktemp`
    rlPhaseEnd

    rlPhaseStartTest "bz1086456 + bz1086572 + bz1098062 + bz1584116"
        rlLog "Check for bz#1086456"
        rlRun "touch /tmp/file"
        rlRun "cat > spec_file <<EOF
/tmp/file -- system_u:object_r:etc_t:s0

EOF"
        rlRun "chcon -t etc_t ./spec_file"
        rlRun -s "setfiles -r -v spec_file /tmp" 1-255
        rlAssertGrep "No such file or directory" $rlRun_LOG
        rm -f $rlRun_LOG


        rlLog "Check for bz#1086572, bz1271326"
        rlRun "setfiles spec_file /tmp/dir_not_exist" 1-255


        rlIsRHEL '<7' && {
            rlLog "Check for bz#1098062"
            rlRun -s "setfiles -q -d spec_file /tmp" 1-255
            rlAssertGrep "mutually exclusive" $rlRun_LOG
            rm -f $rlRun_LOG
        }
    rlPhaseEnd

    rlPhaseStartTest "setfiles should not abort when it can't label a file - bz#1794518"
        USER=$(mktemp -u userXXXX)
        USERTMP=$(mktemp -d)
        rlRun "useradd ${USER}"
        rlRun "
chown ${USER} ${USERTMP}
mkdir -p ${USERTMP}/1/1 ${USERTMP}/1/2
mkdir -p ${USERTMP}/2/1 ${USERTMP}/2/2
mkdir -p ${USERTMP}/3/4
mkdir -p ${USERTMP}/5/6
touch ${USERTMP}/3/4/i
chown -R ${USER} ${USERTMP}
chown root: ${USERTMP}/1/2
chattr +i ${USERTMP}/3/4/i
" 0,1 "Prepare directory structure"
        rlRun "su ${USER} -c '/usr/sbin/setfiles -v -r ${USERTMP} /etc/selinux/targeted/contexts/files/file_contexts ${USERTMP}'"
        rlRun "userdel -r ${USER}"
        chattr -i ${USERTMP}/3/4/i
        rlRun "rm -rf ${USERTMP}"
    rlPhaseEnd
    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

