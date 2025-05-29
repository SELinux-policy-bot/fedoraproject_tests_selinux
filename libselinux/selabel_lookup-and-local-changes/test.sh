#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

PATHS="/rc.d/init.d/test42XYZ-selabel
/usr/bin/test42XYZ-selabel_lookup
/var/lib/test42XYZ-selabel_lookup/bestmatch"

PATHSPECS='/rc\.d/init\.d/test42XYZ-(selabel|lookup)
/usr/bin/test42XYZ-selabel_lookup
/var/lib/test42XYZ-selabel_lookup(/.*)?'

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "pushd $tmp"
        rlRun "set -o pipefail"
    rlPhaseEnd

    rlPhaseStartTest
        echo -n '' > test-selabel-lookup.cil
        for pathspec in $PATHSPECS; do
            echo "(filecon \"${pathspec}\" file (system_u object_r shell_exec_t ((s0) (s0))))" >> test-selabel-lookup.cil
        done
        rlRun "cat test-selabel-lookup.cil"
        rlRun "semodule -i test-selabel-lookup.cil"
        for path in $PATHS; do
            rlRun -s "selabel_lookup -b file -k ${path}"
            rlAssertGrep shell_exec_t $rlRun_LOG
        done
        for pathspec in $PATHSPECS; do
            rlRun "semanage fcontext -a -t bin_t '${pathspec}'"
        done
        rlRun "semanage fcontext -l -C"
        for path in $PATHS; do
            rlRun -s "selabel_lookup -b file -k ${path}"
            rlAssertGrep bin_t $rlRun_LOG

            echo $?
            rlRun "matchpathcon ${path}"
        done
        for pathspec in $PATHSPECS; do
            rlRun "semanage fcontext -d -t bin_t '${pathspec}'"
        done
        rlRun "semodule -r test-selabel-lookup"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
