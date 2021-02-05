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
        USERTMP=$(mktemp -d -p /var/tmp)
        rlRun "useradd ${USER}"
        rlRun "cat > ${USERTMP}/spec_file <<EOF
/   -d system_u:object_r:default_t:s0
/.*  system_u:object_r:default_t:s0
EOF"
        DIRS="${USERTMP}/1/1 ${USERTMP}/1/2 ${USERTMP}/2/2 ${USERTMP}/3/4 ${USERTMP}/5/6"
        rlRun "
for DIR in ${DIRS}; do
    mkdir -p \${DIR}
done
touch ${USERTMP}/1/1/${USER} ${USERTMP}/3/4/chattr
chown -R ${USER} ${USERTMP}
mkdir -p ${USERTMP}/2/1
touch ${USERTMP}/2/1/root
chattr +i ${USERTMP}/3/4/chattr
" 0,1 "Prepare directory structure"
        rlRun "su ${USER} -c '/usr/sbin/setfiles -F -d -v -r ${USERTMP} ${USERTMP}/spec_file ${USERTMP}'" 0-255
        for DIR in ${DIRS}; do
            CONTEXT=$(secon --prompt --file ${DIR})
            rlAssertEquals "${DIR}" ${CONTEXT} "system_u:object_r:default_t:s0"
        done
        CONTEXT=$(secon --prompt --file ${USERTMP}/1/1/${USER})
        rlAssertEquals "${USERTMP}/1/1/${USER}" ${CONTEXT} "system_u:object_r:default_t:s0"
        CONTEXT=$(secon --prompt --file ${USERTMP}/2/1)
        rlAssertNotEquals "${USERTMP}/2/1" ${CONTEXT} "system_u:object_r:default_t:s0"
        CONTEXT=$(secon --prompt --file ${USERTMP}/2/1/root)
        rlAssertNotEquals "${USERTMP}/2/1/root" ${CONTEXT} "system_u:object_r:default_t:s0"
        CONTEXT=$(secon --prompt --file ${USERTMP}/3/4/chattr)
        rlAssertNotEquals "${USERTMP}/3/4/chattr" ${CONTEXT} "system_u:object_r:default_t:s0"
        chattr -i ${USERTMP}/3/4/chattr
        rlRun "rm -rf ${USERTMP}"
        rlRun "userdel -r ${USER}"
    rlPhaseEnd
    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

