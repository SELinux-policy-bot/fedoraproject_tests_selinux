#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm libsepol
        rlAssertRpm libsemanage
        rlAssertRpm libselinux
        rlAssertRpm policycoreutils
        rlRun "rm -f setools*.src.rpm"
        rlRun "yumdownloader --source setools"
        rlRun "ls -l setools*src.rpm"
    rlPhaseEnd

    rlPhaseStartTest "bz#2251915 + RHEL-18067"
        if rlIsRHEL ; then
            rlRun "yum-builddep -y setools --enablerepo '*CRB'"
        elif rlIsCentOS ; then
            rlRun "yum-builddep -y setools --enablerepo crb"
        else # Fedora
            rlRun "yum-builddep -y setools"
        fi
        rlRun "rpmbuild --rebuild setools*.src.rpm"
        rlRun "ls -lR ~/rpmbuild/RPMS | grep setools"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f setools*.src.rpm"
    rlPhaseEnd
rlJournalEnd

