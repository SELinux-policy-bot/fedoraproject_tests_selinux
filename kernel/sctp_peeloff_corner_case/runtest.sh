#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2024 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

function installDepsYum() {
    local yum="$1"; shift

    if "$yum" install --help | grep -q -- --skip-unavailable; then
        "$yum" install -y --skip-unavailable $*
    elif "$yum" install --help | grep -q -- --skip-broken; then
        "$yum" install -y --skip-broken $*
    else
        for req in $*; do
            if ! rpm -q --quiet --whatprovides "$req"; then
                "$yum" install -y "$req" || true
            fi
        done
    fi
}

function installDeps() {
    if [ -e /run/ostree-booted ]; then
        for item in "$@"; do
            if ! rpm -q --quiet --whatprovides "$item"; then
                rpm-ostree --apply-live -y install "$item"
            fi
        done
    elif type yum >/dev/null; then
        installDepsYum yum "$@"
    elif type dnf >/dev/null; then
        installDepsYum dnf "$@"
    fi
}

function check_avc_begin() {
    sleep 1.1
    date +'%x %T'
    sleep 1.1
}

function check_avc_end() {
    marker="marker-$RANDOM"

    auditctl -m "$marker"

    for (( i = 0; i < 100; i++ )); do
        if ausearch -i -m user -ts $1 2>/dev/null </dev/null | \
            grep -q "$marker"
        then
            echo $i
            break
        fi
        sleep 0.1
    done

    ausearch -i -m avc -ts $1 </dev/null
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r" 0 "Print kernel version"
        # Determine the base kernel package name and version corresponding
        # to the currently running kernel. Use this information to derive
        # the correct kernel subpackages to install.
        if KERNEL_CORE_NVRA="$(rpm -qf "/lib/modules/$(uname -r)/config")"; then
            KERNEL_CORE_NV="${KERNEL_CORE_NVRA%-*}"
            KERNEL_CORE_N="${KERNEL_CORE_NV%-*}"

            KERNEL_PKG_VRA="${KERNEL_CORE_NVRA#$KERNEL_CORE_N-}"
            KERNEL_PKG_BASE="${KERNEL_CORE_N%-core}"

            rlLog "Detected kernel package base name '$KERNEL_PKG_BASE' and version-release.arch '$KERNEL_PKG_VRA'"
            rlRun "installDeps  $KERNEL_PKG_BASE-modules-extra-$KERNEL_PKG_VRA" 0 "Install extra kernel modules"
        else
            rlLog "Detected non-RPM running kernel - no extra kernel packages will be installed"
        fi

        rlRun "gcc -O2 -Wall -o reproducer reproducer.c -lsctp" 0 \
                "Compile the reproducer"
        rlRun "modprobe sctp" 0 "Ensure SCTP module is loaded"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "audit_ts=\"\$(check_avc_begin)\""

        rlRun "./reproducer" 0 "Run the reproducer"

        rlRun "check_avc_end \"\$audit_ts\"" 1 "Check if there are AVC denials"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f reproducer"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
