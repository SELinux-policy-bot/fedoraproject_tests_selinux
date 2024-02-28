#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    CUR_VERSION=`rpm -q --qf "%{version}" policycoreutils | head -n 1`
    if rlTestVersion ${CUR_VERSION} '<' 3.6 ; then
        rlLog "The installed SELinux userspace does NOT support the notself/other keywords."
        rlLog "The automated test is NOT relevant for this environment."
        rlJournalEnd
        exit 0
    fi

    rlPhaseStartSetup
        rlAssertRpm libsepol
        rlAssertRpm libsemanage
        rlAssertRpm libselinux
        rlAssertRpm policycoreutils
        rlAssertRpm selinux-policy

        rlRun "setenforce 1"
        rlRun "sestatus"
    rlPhaseEnd

    rlPhaseStartTest "rules defined via the 'notself' keyword"
        rlRun "semodule -lfull | grep notself-module" 1
        rlRun "seinfo -t | grep -vi Types: | wc -l"
        # FIXME: seinfo output contains 1 empty line
        NO_TYPES_BEFORE=`seinfo -t | grep -vi Types: | wc -l`
        rlRun "sesearch -A | wc -l"
        NO_ALLOWS_BEFORE=`sesearch -A | wc -l`
        rlRun "semodule -i notself-module.cil"
        rlRun "semodule -lfull | grep notself-module"
        rlRun "seinfo -t | grep -vi Types: | wc -l"
        # FIXME: seinfo output contains 1 empty line
        NO_TYPES_AFTER=`seinfo -t | grep -vi Types: | wc -l`
        rlRun "sesearch -A | wc -l"
        NO_ALLOWS_AFTER=`sesearch -A | wc -l`
        rlLog "${NO_ALLOWS_BEFORE} + ${NO_TYPES_BEFORE} - 1 = ${NO_ALLOWS_AFTER}"
        # FIXME: -1 is used because seinfo output contains 1 empty line
        rlAssertEquals "the number of allow rules grows because of the 'notself' usage" $(( NO_ALLOWS_BEFORE + NO_TYPES_BEFORE - 1 )) $NO_ALLOWS_AFTER
        rlRun "sesearch -A | grep notself" 1
        rlRun "semodule -r notself-module"
    rlPhaseEnd

    rlPhaseStartTest "rules defined via the 'other' keyword"
        rlRun "semodule -lfull | grep other-module" 1
        rlRun "seinfo -t a_t -x | grep -i 'types: *0'"
        rlRun "sesearch -s a_t -A" 1
        rlRun "semodule -i other-module.cil"
        rlRun "semodule -lfull | grep other-module"
        rlRun "seinfo -t a_t -x | grep -C 1 -i 'types: *1'"
        rlRun "sesearch -A | grep other" 1
        rlLog "the 'other' keyword should NOT generate any allow rules where scontext = tcontext"
        rlRun "sesearch -s a_t -t a_t -A | grep allow" 1
        rlRun "sesearch -s b_t -t b_t -A | grep allow" 1
        rlRun "sesearch -s c_t -t c_t -A | grep allow" 1
        rlLog "the 'other' keyword should generate allow rules where scontext != tcontext"
        rlRun "sesearch -s a_t -t b_t -A | grep allow"
        rlRun "sesearch -s a_t -t c_t -A | grep allow"
        rlRun "sesearch -s b_t -t a_t -A | grep allow"
        rlRun "sesearch -s b_t -t c_t -A | grep allow"
        rlRun "sesearch -s c_t -t a_t -A | grep allow"
        rlRun "sesearch -s c_t -t b_t -A | grep allow"
        rlRun "semodule -r other-module"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalEnd

