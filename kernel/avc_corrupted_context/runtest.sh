#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print running kernel version"
        rlServiceStart memcached
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "semodule -d memcached" 0
        rlRun "ps -Zp \$(pidof memcached) | grep unlabeled_t" 0 \
            "The service should be unlabeled now"
        rlRun "load_policy" 0
        rlRun "semodule -e memcached" 0
        rlRun "ps -Zp \$(pidof memcached) | grep unlabeled_t" 1 \
            "The service shouldn't stay unlabeled"
        rlRun "ps -Zp \$(pidof memcached) | grep system_r:memcached_t:s0" 0 \
            "The service should have the correct label"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "setenforce 0" 0 # service may be unlabeled
        rlServiceStop memcached
        rlRun "setenforce 1" 0
        rlServiceRestore memcached
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
