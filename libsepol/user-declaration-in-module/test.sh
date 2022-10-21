#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Petr Lautrbach <plautrba@redhat.com>

. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "cp foo.te $tmp"
        rlRun "pushd $tmp"
        rlRun "set -o pipefail"
        rlAssertRpm "libsepol"
        rlAssertRpm "selinux-policy-devel"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "make -f /usr/share/selinux/devel/Makefile foo.pp" 0 "Build a module with user declaration"
        rlRun "semodule -i foo.pp" 0
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "semodule -r foo" 0
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
