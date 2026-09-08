#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libsemanage/Sanity/sort-local-fcontexts-in-semanage-conf
#   Description: Verify sort-local-fcontexts in semanage.conf
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="libsemanage"
SEMANAGE_CONF="/etc/selinux/semanage.conf"

set_sort_local_fcontexts()
{
    rlRun "sed -i '/^sort-local-fcontexts=/d' ${SEMANAGE_CONF}"
    rlRun "echo -e '\nsort-local-fcontexts=$1\n' >> ${SEMANAGE_CONF}"
    rlRun "semodule -B"
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlAssertRpm ${PACKAGE}
        rlRun "TmpDir=\$(mktemp -d)" 0 "Create temporary directory"
        rlRun "semanage fcontext -a -t bin_t '${TmpDir}/subdir/specific(/.*)?'"
        rlRun "semanage fcontext -a -t etc_t '${TmpDir}/subdir(/.*)?'"
        rlRun "semanage fcontext -a -t samba_share_t '/shared/samba(/.*)?'"
        rlRun "semanage fcontext -a -t public_content_t '/shared(/.*)?'"

    rlPhaseEnd

    rlPhaseStartTest "sort-local-fcontexts is documented in semanage.conf(5)"
        rlRun "man semanage.conf | col -b | grep -A 3 sort-local-fcontexts"
    rlPhaseEnd

    rlPhaseStartTest "default behavior keeps insertion-order matching"
        rlSEMatchPathCon "${TmpDir}/subdir/specific/file" "etc_t"
        rlSEMatchPathCon "/shared/samba" "public_content_t"
    rlPhaseEnd
    
    rlPhaseStartTest "sort-local-fcontexts=false keeps insertion-order matching"
        rlFileBackup ${SEMANAGE_CONF}
        set_sort_local_fcontexts "false"
        rlSEMatchPathCon "${TmpDir}/subdir/specific/file" "etc_t"
        rlSEMatchPathCon "/shared/samba" "public_content_t"
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartTest "sort-local-fcontexts=true file_contexts.local file is sorted from least to most specific"
        rlFileBackup ${SEMANAGE_CONF}
        set_sort_local_fcontexts "true"
        rlSEMatchPathCon "${TmpDir}/subdir/specific/file" "bin_t"
        rlSEMatchPathCon "/shared/samba" "samba_share_t"
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf ${TmpDir}" 0 "Remove temporary directory"
        rlRun "semanage fcontext -d '${TmpDir}/subdir/specific(/.*)?'"
        rlRun "semanage fcontext -d '${TmpDir}/subdir(/.*)?'"
        rlRun "semanage fcontext -d '/shared/samba(/.*)?'"
        rlRun "semanage fcontext -d '/shared(/.*)?'"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
