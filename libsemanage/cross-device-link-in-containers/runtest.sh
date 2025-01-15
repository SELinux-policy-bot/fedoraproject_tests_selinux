#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libsemanage/Regression/cross-device-link-in-containers
#   Description: Does rebuild of policy affect layered containers?
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

PACKAGE="libsemanage"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm podman
        rlRun "semodule -lfull | grep -e container -e podman"
        rlRun "getsebool -a | grep -e container -e podman"
        rlRun "mkdir selinux1 selinux2"
    rlPhaseEnd

    rlPhaseStartTest "bz#2068085"
        rlRun "pushd selinux1"
        if rlIsCentOS 8 || rlIsRHEL 8 ; then
            STREAM_ID="centos/centos:stream8"
        elif rlIsCentOS 9 || rlIsRHEL 9 ; then
            STREAM_ID="centos/centos:stream9"
        elif rlIsCentOS 10 || rlIsRHEL 10 ; then
            STREAM_ID="centos/centos:stream10"
        else
            STREAM_ID="fedora/fedora:rawhide"
        fi
cat <<EOF >> ./Dockerfile
FROM quay.io/${STREAM_ID}
RUN dnf install -y selinux-policy selinux-policy-targeted
EOF
        rlRun "cat ./Dockerfile"
        rlRun -s "podman build -t localhost/selinux . --no-cache"
        rlAssertGrep "^complete" $rlRun_LOG -i
        rlAssertGrep "^commit" $rlRun_LOG -i
        rlAssertNotGrep "not supported" $rlRun_LOG -i
        rlRun "popd"

        rlRun "pushd selinux2"
cat <<EOF >> ./Dockerfile
FROM localhost/selinux
RUN semodule -B
EOF
        rlRun "cat ./Dockerfile"
        rlRun -s "podman build -t localhost/selinux2 . --no-cache"
        rlAssertNotGrep "error" $rlRun_LOG -i
        rlAssertNotGrep "failed" $rlRun_LOG -i
        rlAssertNotGrep "not supported" $rlRun_LOG -i
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf selinux1 selinux2"
        rlRun "podman images"
        for ID in `podman images -q` ; do
           rlRun "podman rmi $ID"
        done
        rlRun "podman images"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

