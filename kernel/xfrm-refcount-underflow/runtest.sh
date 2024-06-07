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
    if type yum >/dev/null; then
        installDepsYum yum "$@"
    elif type dnf >/dev/null; then
        installDepsYum dnf "$@"
    fi
}

rlJournalStart
    rlPhaseStartSetup
        # Determine the base kernel package name and version corresponding
        # to the currently running kernel. Use this information to derive
        # the correct kernel subpackages to install.
        if KERNEL_CORE_NVRA="$(rpm -qf "/lib/modules/$(uname -r)/kernel")"; then
            KERNEL_CORE_NV="${KERNEL_CORE_NVRA%-*}"
            KERNEL_CORE_N="${KERNEL_CORE_NV%-*}"

            KERNEL_PKG_VRA="${KERNEL_CORE_NVRA#$KERNEL_CORE_N-}"
            KERNEL_PKG_BASE="${KERNEL_CORE_N%-core}"

            rlLog "Detected kernel package base name '$KERNEL_PKG_BASE' and version-release.arch '$KERNEL_PKG_VRA'"
            KERNEL_PKGS="$KERNEL_PKG_BASE-devel-$KERNEL_PKG_VRA"
        else
            rlLog "Detected non-RPM running kernel - no extra kernel packages will be installed"
            KERNEL_PKGS=""
        fi

        rlRun "installDeps systemtap $KERNEL_PKGS" 0 "Install requires"
    rlPhaseEnd

    rlPhaseStartTest
        function dump_xfrm_refcount() {
            local refcount_addr="0x$(grep selinux_xfrm_refcount /proc/kallsyms | cut -f 1 -d ' ')"
            stap -e "probe begin {
                printf(\"%i\\n\", atomic_read($refcount_addr))
                exit()
            }"
        }
        rlRun "dump_xfrm_refcount"
        rlAssertEquals "Assert that XFRM refcount is zero at the beginning" \
            "$(dump_xfrm_refcount)" 0
        rlRun "ip xfrm policy add src 127.0.0.1 dst 127.0.0.1 proto tcp dir out tmpl proto ah mode transport level required" 0 \
            "Add a dummy XFRM policy entry"
        rlRun "ip xfrm state add src 127.0.0.1 dst 127.0.0.1 proto ah spi 0x200 auth sha1 0123456789012345" 0 \
            "Add a dummy XFRM state entry"
        rlRun "ip xfrm policy flush" 0 "Clear XFRM policy entries"
        rlRun "ip xfrm state flush" 0 "Clear XFRM state entries"
        rlRun "dump_xfrm_refcount"
        rlAssertEquals "Assert that XFRM refcount is still zero" \
            "$(dump_xfrm_refcount)" 0
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
