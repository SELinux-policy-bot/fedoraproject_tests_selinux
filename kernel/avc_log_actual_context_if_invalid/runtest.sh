# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2022 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

EXE4="reproducer4"
EXE6="reproducer6"
PORT=8000

UNLABELED_CONTEXT="system_u:object_r:unlabeled_t:s0"
INVALID_TCONTEXT="system_u:object_r:banana_t:s0"
INVALID_SCONTEXT="system_u:system_r:tor_t:s0"
INVALID_SCONTEXT_MODULE="tor"

GARBAGE_TCONTEXT="kuřecí řízek"
GARBAGE_TCONTEXT_AUDIT="6B75C5996563C3AD20C599C3AD7A656B"

rlJournalStart
    rlPhaseStartSetup
        rlImport "selinux-policy/common" # for audit daemon handling

        rlRun "uname -r" 0 "Print running kernel version"

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        old_enforce=$(getenforce)
        rlLog "Backing up SELinux status: $old_enforce"
        rlRun "setenforce 0" 0 "Switching to permissive"
    rlPhaseEnd

    # helper function for subtests:
    function check_avcs() {
        local field_main="$1"
        local field_raw="$2"
        local invalid_ctx="$3"

        rlRun "LANG=en_US ausearch --input-logs -ts $audit_ts --raw -m AVC | \
            grep -E '^type=AVC .* $field_main=$UNLABELED_CONTEXT' \
            >tmpavcs" 0 "Collect AVCs"

        unlabeled_avcs=$(cat tmpavcs | wc -l)
        unlabeled_avcs_with_rawcon=$(cat tmpavcs | \
            grep " $field_raw=$invalid_ctx" | wc -l)
        rlAssertEquals "Check that all AVCs with $field_main=unlabeled have $field_raw= with the correct label" \
            $unlabeled_avcs $unlabeled_avcs_with_rawcon
        rlRun "cat tmpavcs" 0 "Print checked AVCs"
    }

    rlPhaseStartTest "trawcon"
        rlRun "touch foo" 0 "Creating the foo test file"
        rlRun "setfattr -n security.selinux -v $INVALID_TCONTEXT foo" 0 \
            "Setting SELinux xattr of foo to an invalid value"

        audit_ts="$(date +'%x %T')"; sleep 1.1
        rlRun "runcon system_u:system_r:sshd_t:s0 cat foo" 0 \
            "Generating AVCs with invalid tcontext"
        check_avcs tcontext trawcon "\"$INVALID_TCONTEXT\""
    rlPhaseEnd

    rlPhaseStartTest "trawcon-garbage"
        rlRun "touch foo" 0 "Creating the foo test file"
        rlRun "setfattr -n security.selinux -v '$GARBAGE_TCONTEXT' foo" 0 \
            "Setting SELinux xattr of foo to a garbage value"

        sleep 1.1; audit_ts="$(date +'%x %T')"; sleep 1.1
        rlRun "runcon system_u:system_r:sshd_t:s0 cat foo" 0 \
            "Generating AVCs with invalid tcontext"
        check_avcs tcontext trawcon "$GARBAGE_TCONTEXT_AUDIT"
    rlPhaseEnd

    rlPhaseStartTest "srawcon"
        function gen_scontext_unlabeled_avc() {
            local fifo="$1"

            # Start bash with tor label, then make it invalid,
            # and try to do something under the invalid label:
            runcon "$INVALID_SCONTEXT" \
                bash -c "cat $fifo > /dev/null; </usr/bin/echo >/dev/null" &
            semodule -d "$INVALID_SCONTEXT_MODULE"
            echo go! >$fifo
            wait %1
            semodule -e "$INVALID_SCONTEXT_MODULE"
        }

        sleep 1.1; audit_ts="$(date +'%x %T')"; sleep 1.1
        rlRun "mkfifo tmpfifo" 0
        rlRun "gen_scontext_unlabeled_avc tmpfifo" 0 \
            "Generating AVCs with invalid scontext"
        check_avcs scontext srawcon "\"$INVALID_SCONTEXT\""
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "setenforce $old_enforce" 0 "Restoring SELinux status"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
