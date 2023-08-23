#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "pushd $tmp"
        rlRun "set -o pipefail"
    rlPhaseEnd

    rlPhaseStartTest "/usr/bin/mysqld_safe"
        rlRun "mkdir policy"
        rlRun "sepolicy generate -p policy --application /usr/bin/mysqld_safe"
        rlRun "cat policy/*fc"
        for dir in `rpm -ql --dump mariadb-server | sed -n -E '\%\/var\/(log|run|lib)[[:graph:]]* [[:alnum:]]* [[:alnum:]]* [[:alnum:]]* 04.*%s%^([^ ]*).*%\1%p'`; do
            rlRun "grep $dir policy/*.fc"
        done
        rlRun "rm -rf policy"
    rlPhaseEnd

    if [ -x /usr/sbin/abrtd ] ; then
    rlPhaseStartTest "/usr/sbin/abrtd"
        rlRun "mkdir policy"
        rlRun "sepolicy generate -p policy --application /usr/sbin/abrtd"
        rlRun "cat policy/*fc"
        for dir in `rpm -ql --dump abrt | sed -n -E '\%\/var\/(log|run|lib)[[:graph:]]* [[:alnum:]]* [[:alnum:]]* [[:alnum:]]* 04.*%s%^([^ ]*).*%\1%p'`; do
            rlRun "grep $dir policy/*.fc"
        done
        rlRun "rm -rf policy"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
