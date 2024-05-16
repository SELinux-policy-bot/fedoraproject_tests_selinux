#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/policycoreutils/Sanity/setfiles_binary
#   Description: setfiles should allow checking given path against binary policy
#   Author: Vit Mojzis <vmojzis@redhat.com>
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
        rlRun "mkdir policy"
        rlRun "pushd policy"
        # download and extract selinux-policy-targeted
        rlRun "dnf download selinux-policy-targeted"
        rlRun "rpm2cpio *.rpm | cpio -idm"
        rlRun "popd"
        # create a mockup of root directory structure
        DIRS="bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  snap  srv  sys tmp  usr  var"
        rlRun "
mkdir testroot
for DIR in ${DIRS}; do
    mkdir -p testroot/\${DIR}
done
"
        rlRun "ls -lZ testroot"
    rlPhaseEnd

    rlPhaseStartTest "setfiles should allow checking given path against binary policy - bz#1973754"
        DIR=$(pwd)
        # run setfiles using system policy
        rlRun "setfiles -r '$DIR/testroot' -nvF /etc/selinux/targeted/contexts/files/file_contexts '$DIR/testroot' &> setfilesout"
        POLICY=$(find "$DIR/policy/etc/selinux/targeted/policy/" -name "policy.*")
        # run the same command using the extracted policy
        rlRun "setfiles -r '$DIR/testroot' -nvF -c '$POLICY' '$DIR/policy/etc/selinux/targeted/contexts/files/file_contexts' '$DIR/testroot' &> setfilesout2"
        rlRun "diff setfilesout setfilesout2" 0
        if [ ! $? -eq 0 ] ; then
            rlRun "cat setfilesout"
            rlRun "cat setfilesout2"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
