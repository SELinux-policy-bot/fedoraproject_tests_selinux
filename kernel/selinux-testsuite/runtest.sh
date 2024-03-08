#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Sanity/serge-testsuite
#   Description: functional test suite for the LSM-based SELinux security module
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"

# Default commit to checkout from the repo.
# This should be updated as needed after verifying that the new version
# doesn't break testing and after applying all necessary tweaks in the TC.
# Run with GIT_BRANCH=master to run the latest upstream version.
DEFAULT_COMMIT="f9f4a604b50eecdc9ff674f1762208f23c15013f"
# Default pull requests to merge before running the test.
# If non-empty, then after checking out GIT_BRANCH the listed upstream pull
# requests (by number) are merged, creating a new temporary local branch.
DEFAULT_PULLS=""
# Default SELinux Patchwork series to apply before running the test.
DEFAULT_PATCHES=""

# Optional test parameter - location of testuite git.
GIT_URL=${GIT_URL:-"https://github.com/SELinuxProject/selinux-testsuite"}

# Optional test parameter - timeout for detecting lost packets
NETWORK_TIMEOUT=${NETWORK_TIMEOUT:-4}

# Optional test parameter - branch containing tests.
if [ -z "$GIT_BRANCH" ]; then
    GIT_BRANCH="$DEFAULT_COMMIT"
    # Use default cherries only if branch is default and they are not overriden
    GIT_PULLS="${GIT_PULLS:-"$DEFAULT_PULLS"}"
    GIT_PATCHES="${GIT_PATCHES:-"$DEFAULT_PATCHES"}"
fi

# DISTRO unset needed for policy devel Makefile... (Beaker sets it to "RHEL-...")
TS_ENV="env -u ARCH -u DISTRO LANG=C"

# Check if pipefail is enabled to restore original setting.
# See: https://unix.stackexchange.com/a/73180
if false | true; then
    PIPEFAIL_ENABLE="set -o pipefail"
    PIPEFAIL_DISABLE="set +o pipefail"
else
    PIPEFAIL_ENABLE=""
    PIPEFAIL_DISABLE=""
fi

function version_le() {
    { echo "$1"; echo "$2"; } | sort -V | tail -n 1 | grep -qx "$2"
}

function kver_ge() { version_le "$1" "$(uname -r)"; }
function kver_lt() { ! kver_ge "$1"; }
function kver_le() { version_le "$(uname -r)" "$1"; }
function kver_gt() { ! kver_le "$1"; }

function installDepsYum() {
    local yum="$1"; shift

    if "$yum" --help | grep -q -- --skip-broken; then
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

function boolGet() {
    getsebool "$1" | cut -d ' ' -f 3
}
function boolSet() {
    getsebool "$1" &>/dev/null || return 0
    setsebool "$1" "$2" || return 1
    [ "$(boolGet "$1")" == "$2" ]
}


rlJournalStart
    rlPhaseStartSetup "Install"
        # Determine the base kernel package name and version corresponding
        # to the currently running kernel. Use this information to derive
        # the correct kernel subpackages to install.
        if KERNEL_CORE_NVRA="$(rpm -qf "/lib/modules/$(uname -r)/config")"; then
            KERNEL_CORE_NV="${KERNEL_CORE_NVRA%-*}"
            KERNEL_CORE_N="${KERNEL_CORE_NV%-*}"

            KERNEL_PKG_VRA="${KERNEL_CORE_NVRA#$KERNEL_CORE_N-}"
            KERNEL_PKG_BASE="${KERNEL_CORE_N%-core}"

            rlLog "Detected kernel package base name '$KERNEL_PKG_BASE' and version-release.arch '$KERNEL_PKG_VRA'"
            KERNEL_PKGS="
                $KERNEL_PKG_BASE-modules-extra-$KERNEL_PKG_VRA
                $KERNEL_PKG_BASE-devel-$KERNEL_PKG_VRA
            "
        else
            rlLog "Detected non-RPM running kernel - no extra kernel packages will be installed"
            KERNEL_PKGS=""
        fi

        # We need to install the kernel-* packages by ourselves, since we need
        # the same versions as the running kernel. And since we already need a
        # reliable package install function, let's just install all the
        # dependencies here. Thus we don't need to maintain duplicate lists of
        # package requirements in many places (RH repo, Fedora kernel dist-git,
        # CKI).
        REQUIRES="
            $KERNEL_PKGS
            /usr/bin/unbuffer
            attr
            audit
            checkpolicy
            curl
            dosfstools
            e2fsprogs
            elfutils-libelf-devel
            expect
            gcc
            git
            grep
            iptables
            jfsutils
            keyutils-libs-devel
            libbpf-devel
            libibverbs-devel
            libselinux-devel
            libselinux-utils
            libsepol-devel
            libuuid-devel
            lksctp-tools-devel
            mktemp
            nc
            netlabel_tools
            net-tools
            nftables
            nmap-ncat
            perl-Test
            perl-Test-Harness
            perl-Test-Simple
            policycoreutils
            policycoreutils-devel
            policycoreutils-python
            python2-lxml
            python3-lxml
            quota
            rdma-core-devel
            selinux-policy-devel
            setools-console
            xfsprogs-devel
        "
        rlRun "installDeps \$REQUIRES" 0 "Install requires"

        # The CRB repo with libbpf-devel might not be enabled on RHEL
        if rlIsRHEL '>=8' && ! [ -e /run/ostree-booted ]; then
            for repo in "rhel-CRB" "beaker-CRB"; do
                rpm -q libbpf-devel &>/dev/null && break
                rlRun "dnf install --enablerepo $repo -y libbpf-devel" 0-255
            done
        fi
    rlPhaseEnd

    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm audit
        rlFileBackup /etc/selinux/semanage.conf
        # run the testsuite in /root to avoid problems with other paths
        rlRun "pushd /root"

        # version_le() sanity check:
        rlRun "version_le 4.10 4.10"
        rlRun "version_le 4.10 4.10.0"
        rlRun "version_le 4.10 4.10.1"
        rlRun "! version_le 4.10 4.9"
        rlRun "! version_le 4.10.0 4.10"

        if [ -d /sys/fs/selinux ]; then
            selinuxfs=/sys/fs/selinux
        else
            selinuxfs=/selinux
        fi

        if rlIsRHEL '<7.3'; then
            use_cil=n
        else
            use_cil=y
        fi
        make_vars="SELINUXFS=$selinuxfs SUPPORTS_CIL=$use_cil"

        # test turns this boolean off
        rlRun "BACKUP_allow_domain_fd_use=\$(boolGet allow_domain_fd_use)"
        rlRun "BACKUP_domain_can_mmap_files=\$(boolGet domain_can_mmap_files)"
        # test expects that domains cannot map files by default
        rlRun "boolSet domain_can_mmap_files off"

        rlRun "setenforce 1"
        rlRun "sestatus"
        if grep 'expand-check' /etc/selinux/semanage.conf; then
            rlRun "sed -i 's/^expand-check[ ]*=.*$/expand-check = 0/' /etc/selinux/semanage.conf"
        else
            rlRun "echo 'expand-check = 0' >>/etc/selinux/semanage.conf"
        fi
        if [ ! -d selinux-testsuite ]; then
            if ! rlRun "git clone $GIT_URL selinux-testsuite" 0; then
                rlLogFatal "Unable to clone the testsuite repo!"
                rlPhaseEnd
                exit 127
            fi
            rlRun "pushd selinux-testsuite"
            if ! rlRun "git checkout $GIT_BRANCH" 0; then
                rlLogFatal "Unable to checkout the requested branch!"
                rlPhaseEnd
                exit 127
            fi
            for _ in $GIT_PULLS $GIT_PATCHES; do
                rlRun "git config --global user.email nobody@redhat.com"
                rlRun "git config --global user.name 'Nemo Nobody'"
                rlRun "git checkout -b testing-cherry-picks" 0
                break
            done
            for pull in $GIT_PULLS; do
                ref="refs/pull/$pull/head"
                if ! rlRun "git fetch origin $ref:$ref" 0; then
                    rlLogFatal "PR merge failed!"
                    rlPhaseEnd
                    exit 127
                fi
                if ! rlRun "git merge --no-edit $ref" 0; then
                    rlLogFatal "PR merge failed!"
                    rlPhaseEnd
                    exit 127
                fi
            done
            $PIPEFAIL_ENABLE
            for pwseries in $GIT_PATCHES; do
                url="https://patchwork.kernel.org/series/$pwseries/mbox/"
                if ! rlRun "curl $url | git am -"; then
                    rlLogFatal "Applying patch failed!"
                    rlPhaseEnd
                    exit 127
                fi
            done
            $PIPEFAIL_DISABLE
            rlRun "popd"
        fi

        rlRun "pushd selinux-testsuite"

        # backup code before making tweaks
        rlFileBackup "."

        if [ "$VERBOSE" = "1" ]; then
            rlRun "sed -i 's/\(use Test::Harness;\)/\1 \$Test::Harness::verbose = TRUE;/' tests/runtests.pl" 0 \
                "Enable verbose output"
        fi

        {
            echo "#ifndef IFF_NAPI"
            echo "#define IFF_NAPI 0x0010"
            echo "#endif"
            echo "#ifndef IFF_NAPI_FRAGS"
            echo "#define IFF_NAPI_FRAGS 0x0020"
            echo "#endif"
            echo "#ifndef IFF_NO_PI"
            echo "#define IFF_NO_PI 0x1000"
            echo "#endif"
        } | rlRun "tee -a tests/tun_tap/tun_common.h" 0 \
            "Harden tun_tap test against missing defs"

        # needed to avoid a flood of AVCs when run via restraint
        # (RHEL-6 doesn't have unconfined_service_t)
        if ! rlIsRHEL '<7'; then
            rlRun "sed -i 's/type unconfined_t;/type unconfined_t, unconfined_service_t;/' policy/test_policy.if" 0
            rlRun "sed -i 's/\\(allow \\\$1 initrc_t:fd use;\\)/\\1 allow \$1 unconfined_service_t:fd use;/' policy/test_policy.if" 0

            rlRun "sed -i '/install_t/d' policy/test_policy.if" 0
                "RHEL 6 doesn't have install_t"
        fi

        exclude_tests=""
        force_tests=""
        for file in ./tests/nnp*/execnnp.c; do
            rlRun "sed -i 's/3\.18/3.9/' $file" 0 \
                "Fix up kernel version in nnp test"
        done
        if rlIsRHEL "<8.2"; then
            rlRun "sed -i '/SUBDIRS += bpf/d;/export CFLAGS += -DHAVE_BPF/d' tests/Makefile" 0 \
                "RHEL < 8.2 doesn't ship libbpf => disable BPF subtests"
        fi
        if rlIsRHEL "<9"; then
            # CONFIG_KEY_DH_OPERATIONS not enabled on RHEL-8 :(
            # on RHEL-7, KEYCTL_DH_COMPUTE is not defined in the header
            exclude_tests+=" keys"
        fi

        rlRun "sed -i 's/tm\.tv_sec = [0-9]*;/tm.tv_sec = $NETWORK_TIMEOUT;/' ./tests/*/*.c" 0 \
            "Tweak timeout in networking tests" # 2 secs is too little for SCTP test

        if [ -e /run/ostree-booted ]; then
            # Fixed by https://github.com/fedora-selinux/selinux-policy/pull/2029,
            # but may not be in all distro streams.
            rlRun "tee -a policy/test_global.te" 0  \
                "Work around missing policy rules" <<EOF

                gen_require(\`
                    attribute domain;
                    type install_t;
                ')
                allow domain install_t:fd use;
EOF
        fi

        if rlIsRHEL; then
            if kver_lt "3.10.0-349"; then
                # c4684bbdac07 [security] selinux: Permit bounded transitions under NO_NEW_PRIVS or NOSUID
                # da74590f6501 [security] selinux: reject setexeccon() on MNT_NOSUID applications with -EACCES
                exclude_tests+=" nnp_nosuid"
            fi

            if kver_lt "3.10.0-693"; then
                # I don't know when exactly these tests start passing, so I'm just
                # disabling them for anything below the RHEL-7.4 kernel...
                exclude_tests+=" inet_socket/tcp inet_socket/udp"
                exclude_tests+=" filesystem/ext4 filesystem/xfs filesystem/jfs filesystem/vfat"
            fi

            if kver_lt "3.10.0-875"; then
                rlLog "No xperms support => disable xperms testing"
                rlRun "sed -i '/TARGETS += test_ioctl_xperms\.te/d' policy/Makefile"
                rlRun "sed -i 's/\$kernver >= 30/\$kernver >= 999999/' tests/ioctl/test"
            fi
            # workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1613056
            # (if running kernel version sorts inside the known-bug window, then
            # we need to apply the workaround)
            if kver_ge "3.10.0-875" && kver_lt "3.10.0-972"; then
                rlLog "Applying workaround for BZ 1613056..."
                rlRun "cat >>policy/test_ipc.te <<<'allow_map(ipcdomain, tmpfs_t, file)'"
                rlRun "cat >>policy/test_mmap.te <<<'allow_map(test_execmem_t, tmpfs_t, file)'"
                rlRun "cat >>policy/test_mmap.te <<<'allow_map(test_no_execmem_t, tmpfs_t, file)'"
            fi

            # work around non-functional ext4 native quota support on
            # RHEL-7
            if kver_lt 4.18; then
                rlRun "sed -i 's/3.6/4.18/g' tests/{fs_,}filesystem/test"
            fi

            if kver_ge 4.18; then
                force_tests+=" sctp"
            fi
            if kver_ge 4.18.0-80.19; then
                force_tests+=" cgroupfs_label"
            fi
            if kver_lt 4.18.0-152; then
                # 2839e8ee09517 [net] sctp: add SCTP_ADDR_MADE_PRIM event
                rlRun "sed -i 's/\\\$test_asconf = 1;/\$test_count -= 3;/g' tests/sctp/test" 0 \
                    "Disable SCTP ASCONF test (not testable on this kernel)"
                # 3add2b6b02518 [net] sctp: add SCTP_SEND_FAILED_EVENT event
                rlRun "sed -i 's/SCTP_SEND_FAILED_EVENT/SCTP_STREAM_CHANGE_EVENT + 1/g' tests/sctp/*.c" 0 \
                    "Fix SCTP test compilation on old RHEL kernels"
            fi
            if kver_lt 4.18.0-252; then
                # 8a4d5985551b [security] selinux: Add xfs quota command types
                script1='s/\$test_count += 62;/$test_count = 55;/g'
                script2='s/\$quota_checks += 1;/$quota_checks = 0;/g'
                # for some reason this is needed for older RHEL 7 versions...
                script3='s/\$test_count += 69;/$test_count = 55;/g'
                rlRun "sed -i -E -e '$script1' -e '$script2' -e '$script3' tests/filesystem/test" 0 \
                    "Apply workaround for missing XFS quota checks"
            fi
            if kver_lt 4.18.0-314; then
                # a17f0671017f selinux: vsock: Set SID for socket returned by accept()
                exclude_tests+=" vsock_socket"
            fi

            sctp_client_peeloff=0
            if kver_ge 4.18.0-305.39.1 && kver_lt 4.18.0-306; then
                sctp_client_peeloff=1
            fi
            if kver_ge 4.18.0-348.19.1 && kver_lt 4.18.0-349; then
                sctp_client_peeloff=1
            fi
            if kver_ge 4.18.0-372.1.1 && kver_lt 5.14; then
                sctp_client_peeloff=1
            fi
            if kver_ge 5.14.0-70.15.1 && kver_lt 5.14.0-71; then
                sctp_client_peeloff=1
            fi
            if kver_ge 5.14.0-84; then
                sctp_client_peeloff=1
            fi
            if [ "$sctp_client_peeloff" -eq 1 ]; then
                rlRun "sed -i 's/5\.18/4.18/g' tests/sctp/test" 0 \
                    "Fix up kernel version in sctp test"
            fi

            # TODO: wait for 786fc12457268cc9b555dde6c22ae7300d4b40e1
            # to be backported
            #if kver_ge 5.14.0-326; then
            #    force_tests+=" inet_socket/mptcp"
            #fi

            if ! grep -q 'CONFIG_SCSI_ISCSI_ATTRS=y' "/lib/modules/$(uname -r)/config"; then
                rlRun "sed -i -e 's/runcon -t test_netlink_iscsi_socket_t/true/' \
                    -e 's/runcon -t test_no_netlink_iscsi_socket_t/false/' \
                    tests/netlink_socket/test" 0 \
                    "Apply workaround for disabled CONFIG_SCSI_ISCSI_ATTRS"
            fi

            if ! grep -q 'CONFIG_QFMT_V2=y' "/lib/modules/$(uname -r)/config"; then
                # patch the filesystem tests to not do quota tests on ext4
                rlRun "sed -i -e 's/\`uname -r\`/\"3.0\"/' \
                    -e 's/\\(elsif ( \$fs_type eq \"nfs4\" or \$fs_type eq \"nfs\"\\)/\\1 or \$fs_type eq \"ext4\"/' \
                    tests/filesystem/test tests/fs_filesystem/test" 0 \
                    "Apply workaround for disabled CONFIG_QFMT_V2"
            fi
        fi

        # CKI mainline kernels don't ship with module build infrastructure
        # just yet. Also, RHEL-8 CKI kernel-devel programs are
        # cross-compiled badly for alt arches, so try executing one of them.
        if ! "/lib/modules/$(uname -r)/build/scripts/basic/fixdep" 2>&1 | grep -q "Usage"; then
            exclude_tests+=" module_load"
        fi

        # CKI kernels are cross-compiled and generate invalid BTF for s390x
        if [ "$(rlGetPrimaryArch)" = s390x ] && [ -r /sys/kernel/btf/vmlinux ]; then
            # Check whether the magic number is stored big-endian
            btf_head="$(head -c 2 /sys/kernel/btf/vmlinux | hexdump -e '/1 "%02x"')"
            if [ "$btf_head" != eb9f ]; then
                exclude_tests+=" bpf"
            fi
        fi

        if [ -n "$exclude_tests" ] ; then
            rlRun "sed -i '/^[^[:space:]]*:\(\| .*\)\$/i SUBDIRS:=\$(filter-out $exclude_tests, \$(SUBDIRS))' tests/Makefile" 0 \
                "Exclude not applicable tests: $exclude_tests"
        fi
        if [ -n "$force_tests" ] ; then
            rlRun "sed -i '/^[^[:space:]]*:\(\| .*\)\$/i SUBDIRS:=\$(filter-out $force_tests, \$(SUBDIRS))\nSUBDIRS += $force_tests' tests/Makefile" 0 \
                "Force applicable tests: $force_tests"
        fi

        # Initialize report.
        rlRun "echo 'Remote: $GIT_URL' >results.log" 0
        rlRun "echo 'Branch: $GIT_BRANCH' >>results.log" 0
        rlRun "echo 'Commit: $(git rev-parse $GIT_BRANCH)' >>results.log" 0
        rlRun "echo 'GH PRs: ${GIT_PULLS:-"(none)"}' >>results.log" 0
        rlRun "echo 'Series: ${GIT_PATCHES:-"(none)"}' >>results.log" 0
        rlRun "echo 'Kernel: $(uname -r)' >>results.log" 0
        rlRun "echo 'Policy: $(rpm -q selinux-policy)' >>results.log" 0
        rlRun "echo '        $(rpm -q checkpolicy)' >>results.log" 0
        rlRun "echo '        $(rpm -q libselinux)' >>results.log" 0
        rlRun "echo '        $(rpm -q libsemanage)' >>results.log" 0
        rlRun "echo '        $(rpm -q libsepol)' >>results.log" 0
        rlRun "echo '        $(rpm -q policycoreutils)' >>results.log" 0
        rlRun "echo '' >>results.log" 0

        rlRun "popd"
        rlRun "AUDIT_FILE=\"\$(mktemp)\""
        rlRun "auditctl -w \"\$AUDIT_FILE\" -p w" 0 \
            "Enable creation of PATH audit records"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "pushd selinux-testsuite"
        rlRun "$TS_ENV make $make_vars" 0
        rlRun "cat results.log" 0
        $PIPEFAIL_ENABLE
        rlRun "$TS_ENV unbuffer make -s test $make_vars 2>&1 | tee -a results.log" 0
        $PIPEFAIL_DISABLE
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "auditctl -W \"\$AUDIT_FILE\" -p w" 0 \
            "Remove rule for creation of PATH audit records"
        rlRun "rm -f \"\$AUDIT_FILE\""
        # rlSEBooleanRestore
        # rlSEBooleanRestore allow_domain_fd_use
        # none of above-mentioned commands is able to correctly restore the value in the boolean
        rlRun "boolSet domain_can_mmap_files $BACKUP_domain_can_mmap_files"
        rlRun "boolSet allow_domain_fd_use $BACKUP_allow_domain_fd_use"

        rlRun "pushd selinux-testsuite"
        # Submit report to beaker.
        rlFileSubmit "results.log" "selinux-testsuite.results.$(uname -r).txt"
        rlRun "$TS_ENV make -s -C policy unload $make_vars" 0-2
        rlRun "$TS_ENV make -s clean $make_vars" 0-2
        rlRun "popd"

        rlRun "sleep 5" 0
        rlRun "dmesg | grep -i \"rcu_sched detected stalls\"" 1

        rlRun "popd" 0 "Leave /root"
        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

