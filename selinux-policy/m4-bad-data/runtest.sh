#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Sanity/m4-bad-data
#   Description: M4 bad-data tests for modular policy preprocessing
#   Author: Akhil Kohli <akkohli@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
POLICY_GIT="${SELINUX_POLICY_GIT:-https://github.com/fedora-selinux/selinux-policy.git}"
POLICY_DIR="${SELINUX_POLICY_SRC:-}"

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="${BASEDIR}/fixtures"

M4=${M4:-m4}
CHECKMODULE=${CHECKMODULE:-checkmodule}
SEMODULE_PACKAGE=${SEMODULE_PACKAGE:-semodule_package}

# Prefer explicit override; otherwise pick a clone branch for local/fallback use.
# Fedora Rawhide may report VERSION_ID=rawhide or a numeric ID ahead of any fN
# branch (e.g. 45 while only rawhide/f44 exist). Clone falls back to rawhide.
if [ -n "${SELINUX_POLICY_BRANCH:-}" ]; then
    POLICY_BRANCH="${SELINUX_POLICY_BRANCH}"
else
    test -e /etc/os-release && os_release='/etc/os-release' || os_release='/usr/lib/os-release'
    # shellcheck disable=SC1090
    . "${os_release}"
    if rlIsOSLike fedora; then
        fedora_rel=""
        if [[ "${VERSION_ID}" =~ ^[0-9]+$ ]]; then
            fedora_rel="${VERSION_ID}"
        elif [[ "${REDHAT_BUGZILLA_PRODUCT_VERSION:-}" =~ ^[0-9]+$ ]]; then
            fedora_rel="${REDHAT_BUGZILLA_PRODUCT_VERSION}"
        elif [[ "${REDHAT_SUPPORT_PRODUCT_VERSION:-}" =~ ^[0-9]+$ ]]; then
            fedora_rel="${REDHAT_SUPPORT_PRODUCT_VERSION}"
        fi
        if [ -n "${fedora_rel}" ]; then
            POLICY_BRANCH="f${fedora_rel}"
        else
            POLICY_BRANCH="rawhide"
        fi
    else
        VERSION="${VERSION_ID%.*}"
        POLICY_BRANCH="c${VERSION}s"
    fi
fi

DEVEL_SUPPORT="/usr/share/selinux/devel/include/support"

# Configure M4SUPPORT/IFERROR from a selinux-policy git checkout layout.
setup_m4_from_git_tree() {
    local root="$1"
    M4SUPPORT="${root}/support/divert.m4 \
        ${root}/policy/support/misc_macros.spt \
        ${root}/policy/support/mls_mcs_macros.spt \
        ${root}/policy/support/loadable_module.spt \
        ${root}/policy/support/obj_perm_sets.spt \
        ${root}/support/undivert.m4"
    IFERROR="${root}/support/iferror.m4"
    POLICY_ROOT="${root}"
}

# Configure M4SUPPORT from installed selinux-policy-devel (flat support/).
setup_m4_from_devel() {
    local support="$1"
    M4SUPPORT="${support}/divert.m4 \
        ${support}/misc_macros.spt \
        ${support}/mls_mcs_macros.spt \
        ${support}/loadable_module.spt \
        ${support}/obj_perm_sets.spt \
        ${support}/undivert.m4"
    # iferror.m4 is build-tree only; recreate the upstream one-liner when absent.
    if [ -f "${support}/iferror.m4" ]; then
        IFERROR="${support}/iferror.m4"
    else
        IFERROR="${OUTDIR}/iferror.m4"
        cat >"${IFERROR}" <<'EOF'
ifdef(`__if_error',`m4exit(1)')
EOF
    fi
    POLICY_ROOT="${support}"
}

# Build all_interfaces.conf from one or more .if files (usual modular M4 recipe).
build_all_interfaces() {
    local out="$1"
    shift

    echo 'divert(-1)' >"${out}"
    # shellcheck disable=SC2086
    ${M4} ${M4PARAM} ${M4SUPPORT} "$@" "${IFERROR}" >"${out}.tmp" 2>"${out}.err"
    local rc=$?
    sed -e 's/dollarsstar/$*/g' "${out}.tmp" >>"${out}"
    echo 'divert' >>"${out}"
    return "${rc}"
}

# Expand a module .te with interfaces (usual modular M4 recipe; /dev/null for gen defs).
expand_module_te() {
    local interfaces="$1"
    local te="$2"
    local out="$3"

    # shellcheck disable=SC2086
    ${M4} ${M4PARAM} -s ${M4SUPPORT} "${EMPTY_GEN_DEF}" "${interfaces}" "${te}" \
        >"${out}" 2>"${out}.err"
    return $?
}

# Expand file_contexts (usual modular M4 recipe for .fc -> .mod.fc).
expand_fc() {
    local fc="$1"
    local out="$2"

    # shellcheck disable=SC2086
    ${M4} ${M4PARAM} ${M4SUPPORT} "${fc}" >"${out}" 2>"${out}.err"
    return $?
}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm checkpolicy
        rlRun "command -v m4"
        rlRun "command -v checkmodule"
        rlRun "command -v semodule_package"

        OUTDIR=$(mktemp -d "${TMPDIR:-/var/tmp}/selinux-policy-m4-bad-data.XXXXXX")
        rlRun "test -d ${OUTDIR}"
        CLONED_POLICY_DIR=""

        # Macro source priority (Petr): explicit checkout > installed devel > git clone.
        if [ -n "${POLICY_DIR}" ]; then
            rlAssertExists "${POLICY_DIR}/Rules.modular"
            setup_m4_from_git_tree "${POLICY_DIR}"
            rlLog "Using SELINUX_POLICY_SRC=${POLICY_DIR}"
        elif [ -f "${DEVEL_SUPPORT}/loadable_module.spt" ]; then
            rlAssertRpm selinux-policy-devel
            setup_m4_from_devel "${DEVEL_SUPPORT}"
            rlLog "Using selinux-policy-devel support macros from ${DEVEL_SUPPORT}"
        else
            CLONED_POLICY_DIR="$(mktemp -d /var/tmp/selinux-policy-src.XXXXXX)"
            rlLog "Cloning ${POLICY_GIT} branch ${POLICY_BRANCH}"
            if rlIsOSLike fedora && [ "${POLICY_BRANCH}" != "rawhide" ]; then
                # fN may not exist yet on Rawhide (e.g. f45); allow failure then retry.
                rlRun "git clone --depth=1 -b ${POLICY_BRANCH} ${POLICY_GIT} ${CLONED_POLICY_DIR}" 0-255
                if [ ! -f "${CLONED_POLICY_DIR}/Rules.modular" ]; then
                    rlLog "Branch ${POLICY_BRANCH} unavailable; falling back to rawhide"
                    rlRun "rm -rf ${CLONED_POLICY_DIR}"
                    CLONED_POLICY_DIR="$(mktemp -d /var/tmp/selinux-policy-src.XXXXXX)"
                    rlRun "git clone --depth=1 -b rawhide ${POLICY_GIT} ${CLONED_POLICY_DIR}"
                fi
            else
                rlRun "git clone --depth=1 -b ${POLICY_BRANCH} ${POLICY_GIT} ${CLONED_POLICY_DIR}"
            fi
            rlAssertExists "${CLONED_POLICY_DIR}/Rules.modular"
            setup_m4_from_git_tree "${CLONED_POLICY_DIR}"
        fi

        # shellcheck disable=SC2086
        rlRun "test -f $(echo ${M4SUPPORT} | awk '{print $1}')"
        rlRun "test -f ${IFERROR}"

        M4PARAM="-D enable_mcs -D distro_redhat -D hide_broken_symptoms -D mls_num_sens=16 -D mls_num_cats=1024 -D mcs_num_cats=1024"
        EMPTY_GEN_DEF=/dev/null

        rlRun "ln -sf /nonexistent/test_good.if ${OUTDIR}/broken_symlink.if"
        rlRun "ln -sf /nonexistent/test_good.mod.fc ${OUTDIR}/broken_symlink.fc"
        rlRun "printf '' > ${OUTDIR}/empty.fc"
    rlPhaseEnd

    # --- .if -> all_interfaces.conf ---
    rlPhaseStartTest "unclosed interface definition"
        rlRun "build_all_interfaces ${OUTDIR}/b1_unclosed.interfaces ${FIXTURES}/interfaces/bad_unclosed.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "broken M4 syntax in interface file"
        rlRun "build_all_interfaces ${OUTDIR}/b1_m4_syntax.interfaces ${FIXTURES}/interfaces/bad_m4_syntax.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "duplicate interface definition"
        rlRun "build_all_interfaces ${OUTDIR}/b1_duplicate.interfaces ${FIXTURES}/interfaces/bad_duplicate.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "broken gen_require block in interface file"
        rlRun "build_all_interfaces ${OUTDIR}/b1_bad_gen_if.interfaces ${FIXTURES}/interfaces/bad_gen_if_build.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "empty interface template name"
        rlRun "build_all_interfaces ${OUTDIR}/b1_empty_ifname.interfaces ${FIXTURES}/interfaces/bad_empty_ifname.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "missing .if path"
        rlRun "build_all_interfaces ${OUTDIR}/b1_missing.interfaces ${OUTDIR}/does_not_exist.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "directory instead of .if file"
        rlRun "build_all_interfaces ${OUTDIR}/b1_directory.interfaces ${BASEDIR}" 1-255
    rlPhaseEnd

    rlPhaseStartTest "broken symlink for .if"
        rlRun "build_all_interfaces ${OUTDIR}/b1_symlink.interfaces ${OUTDIR}/broken_symlink.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "unreadable .if file"
        if [ "$(id -u)" -eq 0 ]; then
            rlLog "SKIP: root can read mode 000 files; unreadable check is non-root only"
        else
            rlRun "cp ${FIXTURES}/interfaces/good.if ${OUTDIR}/unreadable.if"
            rlRun "chmod 000 ${OUTDIR}/unreadable.if"
            rlRun "build_all_interfaces ${OUTDIR}/unreadable_if.interfaces ${OUTDIR}/unreadable.if" 1-255
        fi
    rlPhaseEnd

    rlPhaseStartTest "control good interface"
        rlRun "build_all_interfaces ${OUTDIR}/b1_good.interfaces ${FIXTURES}/interfaces/good.if"
        rlRun "test -s ${OUTDIR}/b1_good.interfaces"
    rlPhaseEnd

    GOOD_IF="${OUTDIR}/b1_good.interfaces"

    # --- .te + M4 with interfaces ---
    rlPhaseStartTest "control good .if + .te through M4 and checkmodule"
        rlRun "expand_module_te ${GOOD_IF} ${FIXTURES}/modules/te_good.te ${OUTDIR}/b2_good.tmp"
        rlRun "test -s ${OUTDIR}/b2_good.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_good.mod ${OUTDIR}/b2_good.tmp"
        rlRun "test -s ${OUTDIR}/te_good.mod"
    rlPhaseEnd

    rlPhaseStartTest "missing .te path at M4 expand"
        rlRun "expand_module_te ${GOOD_IF} ${OUTDIR}/does_not_exist.te ${OUTDIR}/b2_missing_te.tmp" 1-255
    rlPhaseEnd

    NEEDS_ARG_IF="${OUTDIR}/needs_arg.interfaces"

    rlPhaseStartTest "interface called with too few arguments"
        rlRun "build_all_interfaces ${NEEDS_ARG_IF} ${FIXTURES}/interfaces/needs_arg.if"
        rlRun "expand_module_te ${NEEDS_ARG_IF} ${FIXTURES}/modules/te_few_args.te ${OUTDIR}/b2_few_args.tmp"
        rlRun "test -s ${OUTDIR}/b2_few_args.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_few.mod ${OUTDIR}/b2_few_args.tmp" 1-255
    rlPhaseEnd

    rlPhaseStartTest "interface called with too many arguments"
        rlLog "DOCUMENT: extra interface args are ignored by M4"
        rlRun "test -s ${NEEDS_ARG_IF}"
        rlRun "expand_module_te ${NEEDS_ARG_IF} ${FIXTURES}/modules/te_many_args.te ${OUTDIR}/b2_many_args.tmp"
        rlRun "test -s ${OUTDIR}/b2_many_args.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_many.mod ${OUTDIR}/b2_many_args.tmp"
        rlRun "test -s ${OUTDIR}/te_many.mod"
    rlPhaseEnd

    # --- M4 OK, bad expanded TE -> checkmodule fails ---
    # bad_trunc.if is unclosed at the M4 interface stage (EOF in string), so it is
    # rejected before module expand — same class of failure as other broken .if files.
    rlPhaseStartTest "truncated allow from interface expansion"
        rlRun "build_all_interfaces ${OUTDIR}/bad_trunc.interfaces ${FIXTURES}/interfaces/bad_trunc.if" 1-255
    rlPhaseEnd

    rlPhaseStartTest "broken gen_require expanded from interface"
        rlRun "build_all_interfaces ${OUTDIR}/bad_gen_require.interfaces ${FIXTURES}/interfaces/bad_gen_require.if"
        rlRun "expand_module_te ${OUTDIR}/bad_gen_require.interfaces ${FIXTURES}/modules/te_gen_require.te ${OUTDIR}/b5_gen_require.tmp"
        rlRun "test -s ${OUTDIR}/b5_gen_require.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_gen_require.mod ${OUTDIR}/b5_gen_require.tmp" 1-255
    rlPhaseEnd

    rlPhaseStartTest "unknown type from interface expansion"
        rlRun "build_all_interfaces ${OUTDIR}/bad_unknown_type.interfaces ${FIXTURES}/interfaces/bad_unknown_type.if"
        rlRun "expand_module_te ${OUTDIR}/bad_unknown_type.interfaces ${FIXTURES}/modules/te_unknown_type.te ${OUTDIR}/b5_unknown_type.tmp"
        rlRun "test -s ${OUTDIR}/b5_unknown_type.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_unknown_type.mod ${OUTDIR}/b5_unknown_type.tmp" 1-255
    rlPhaseEnd

    rlPhaseStartTest "unknown permission from interface expansion"
        rlRun "build_all_interfaces ${OUTDIR}/bad_unknown_perm.interfaces ${FIXTURES}/interfaces/bad_unknown_perm.if"
        rlRun "expand_module_te ${OUTDIR}/bad_unknown_perm.interfaces ${FIXTURES}/modules/te_unknown_perm.te ${OUTDIR}/b5_unknown_perm.tmp"
        rlRun "test -s ${OUTDIR}/b5_unknown_perm.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_unknown_perm.mod ${OUTDIR}/b5_unknown_perm.tmp" 1-255
    rlPhaseEnd

    rlPhaseStartTest "garbage token from interface expansion"
        rlRun "build_all_interfaces ${OUTDIR}/bad_garbage.interfaces ${FIXTURES}/interfaces/bad_garbage.if"
        rlRun "expand_module_te ${OUTDIR}/bad_garbage.interfaces ${FIXTURES}/modules/te_garbage.te ${OUTDIR}/b5_garbage.tmp"
        rlRun "test -s ${OUTDIR}/b5_garbage.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_garbage.mod ${OUTDIR}/b5_garbage.tmp" 1-255
    rlPhaseEnd

    rlPhaseStartTest "invalid module line from interface expansion"
        rlRun "build_all_interfaces ${OUTDIR}/bad_module_line.interfaces ${FIXTURES}/interfaces/bad_module_line.if"
        rlRun "expand_module_te ${OUTDIR}/bad_module_line.interfaces ${FIXTURES}/modules/te_bad_module_line.te ${OUTDIR}/b5_module_line.tmp"
        rlRun "test -s ${OUTDIR}/b5_module_line.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/te_bad_mod.mod ${OUTDIR}/b5_module_line.tmp" 1-255
    rlPhaseEnd

    # --- .fc -> M4 -> .mod.fc ---
    rlPhaseStartTest "control good .fc through M4"
        rlRun "expand_fc ${FIXTURES}/file_contexts/good.fc ${OUTDIR}/b3_good.mod.fc"
        rlRun "test -s ${OUTDIR}/b3_good.mod.fc"
    rlPhaseEnd

    rlPhaseStartTest "invalid context survives M4"
        rlLog "DOCUMENT: labeling validation deferred to sefcontext_compile"
        rlRun "expand_fc ${FIXTURES}/file_contexts/bad_context.fc ${OUTDIR}/b3_bad_context.mod.fc"
        rlRun "test -s ${OUTDIR}/b3_bad_context.mod.fc"
    rlPhaseEnd

    rlPhaseStartTest "wrong field count in .fc"
        rlLog "DOCUMENT: labeling validation deferred to sefcontext_compile"
        rlRun "expand_fc ${FIXTURES}/file_contexts/bad_fields.fc ${OUTDIR}/b3_bad_fields.mod.fc"
        rlRun "test -s ${OUTDIR}/b3_bad_fields.mod.fc"
    rlPhaseEnd

    rlPhaseStartTest "empty .fc file"
        rlLog "DOCUMENT: labeling validation deferred to sefcontext_compile"
        rlRun "expand_fc ${OUTDIR}/empty.fc ${OUTDIR}/b3_empty_fc.mod.fc"
    rlPhaseEnd

    rlPhaseStartTest "path-only line without context in .fc"
        rlLog "DOCUMENT: labeling validation deferred to sefcontext_compile"
        rlRun "expand_fc ${FIXTURES}/file_contexts/bad_no_context.fc ${OUTDIR}/b3_no_context.mod.fc"
        rlRun "test -s ${OUTDIR}/b3_no_context.mod.fc"
    rlPhaseEnd

    rlPhaseStartTest "invalid regex metacharacters in .fc path"
        rlLog "DOCUMENT: labeling validation deferred to sefcontext_compile"
        rlRun "expand_fc ${FIXTURES}/file_contexts/bad_regex.fc ${OUTDIR}/b3_bad_regex.mod.fc"
        rlRun "test -s ${OUTDIR}/b3_bad_regex.mod.fc"
    rlPhaseEnd

    rlPhaseStartTest "missing .fc path"
        rlRun "expand_fc ${OUTDIR}/does_not_exist.fc ${OUTDIR}/b3_missing.mod.fc" 1-255
    rlPhaseEnd

    rlPhaseStartTest "directory instead of .fc file"
        rlRun "expand_fc ${BASEDIR} ${OUTDIR}/b3_directory.mod.fc" 1-255
    rlPhaseEnd

    rlPhaseStartTest "broken symlink for .fc"
        rlRun "expand_fc ${OUTDIR}/broken_symlink.fc ${OUTDIR}/b3_symlink.mod.fc" 1-255
    rlPhaseEnd

    rlPhaseStartTest "unreadable .fc file"
        if [ "$(id -u)" -eq 0 ]; then
            rlLog "SKIP: root can read mode 000 files; unreadable check is non-root only"
        else
            rlRun "cp ${FIXTURES}/file_contexts/good.fc ${OUTDIR}/unreadable.fc"
            rlRun "chmod 000 ${OUTDIR}/unreadable.fc"
            rlRun "expand_fc ${OUTDIR}/unreadable.fc ${OUTDIR}/unreadable_fc.mod.fc" 1-255
        fi
    rlPhaseEnd

    rlPhaseStartTest "broken M4 syntax in .fc"
        rlRun "expand_fc ${FIXTURES}/file_contexts/bad_m4_syntax.fc ${OUTDIR}/b3_bad_m4.mod.fc" 1-255
    rlPhaseEnd

    # --- M4-expanded .mod.fc through semodule_package (E2E; labeling deferred) ---
    rlPhaseStartTest "bad M4-expanded .mod.fc packaged with good .mod"
        rlLog "DOCUMENT: M4 to package E2E; labeling validation deferred to sefcontext_compile"
        rlRun "mkdir -p ${OUTDIR}/b6_e2e_build"
        rlRun "expand_module_te ${GOOD_IF} ${FIXTURES}/modules/te_good.te ${OUTDIR}/b6_e2e.tmp"
        rlRun "${CHECKMODULE} -M -m -o ${OUTDIR}/b6_e2e_build/te_good.mod ${OUTDIR}/b6_e2e.tmp"
        rlRun "expand_fc ${FIXTURES}/file_contexts/bad_context.fc ${OUTDIR}/b6_e2e.mod.fc"
        rlRun "${SEMODULE_PACKAGE} -o ${OUTDIR}/b6_e2e.pp -m ${OUTDIR}/b6_e2e_build/te_good.mod -f ${OUTDIR}/b6_e2e.mod.fc"
        rlRun "test -s ${OUTDIR}/b6_e2e.pp"
    rlPhaseEnd

    rlPhaseStartCleanup
        if [ -n "${OUTDIR:-}" ] && [ -d "${OUTDIR}" ]; then
            rlRun "rm -rf ${OUTDIR}"
        fi
        if [ -n "${CLONED_POLICY_DIR:-}" ] && [ -d "${CLONED_POLICY_DIR}" ]; then
            rlRun "rm -rf ${CLONED_POLICY_DIR}"
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
