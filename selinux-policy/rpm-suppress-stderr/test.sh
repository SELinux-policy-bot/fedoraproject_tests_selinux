#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
. /usr/share/beakerlib/beakerlib.sh || exit 1

INSTALL_OPTION=""
DOWNLOAD_OPTION=""
if dnf --help | grep -q use-host-config ; then
    INSTALL_OPTION="${INSTALL_OPTION} --use-host-config"
fi
if rlIsCentOS 9 ; then
    INSTALL_OPTION="${INSTALL_OPTION} --releasever 9"
elif rlIsFedora ; then
    RELEASEVER=`grep VERSION_ID /etc/os-release | cut -d = -f 2`
    INSTALL_OPTION="${INSTALL_OPTION} --releasever ${RELEASEVER}"
fi
DOWNLOAD_OPTION=${INSTALL_OPTION}
# dnf sometimes fails to detect the release version on CentOS 9
if dnf install --help | grep -q skip-broken ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-broken"
fi
if dnf install --help | grep -q skip-unavailable ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-unavailable"
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "pushd $tmp"
        rlRun "set -o pipefail"
        rlAssertRpm fuse
	rlAssertRpm fuse-overlayfs
    rlPhaseEnd

    rlPhaseStartTest
	rlRun "mkdir $tmp/lower $tmp/upper $tmp/work $tmp/merged"
	rlRun "dnf -y install --installroot=$tmp/lower diffutils libfdisk libselinux-utils libutempter policycoreutils util-linux rpm ${INSTALL_OPTION}"
	rlRun "mkdir download"
	rlRun "cd download"
	rlRun "dnf download rpm-plugin-selinux selinux-policy selinux-policy-targeted ${DOWNLOAD_OPTION}"
	rlRun "mv -v *rpm $tmp/lower"
	rlRun "cd .."
	rlRun "fuse-overlayfs -o lowerdir=$tmp/lower/ -o upperdir=$tmp/upper/ -o workdir=$tmp/work/ $tmp/merged/"
	RPMS=$(ls $tmp/merged/ | grep .rpm | xargs)
	rlRun "chroot $tmp/merged/ /usr/bin/rpm -i $RPMS 2> error.log"
    # warnings can be ignored/removed
    rlRun "sed -i 's/^warning.*$//' error.log"
    # whitespaces can be ignored/removed
    rlRun "sed -i 's/^[[:space:]]*$//' error.log"
    rlRun "sed -i '/^$/d' error.log"
	rlAssert0 "error.log should be empty" `stat -c "%s" error.log`
	rlRun "cat error.log"
	rlRun "fusermount -u $tmp/merged/"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
