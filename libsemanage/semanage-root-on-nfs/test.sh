#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
. /usr/share/beakerlib/beakerlib.sh || exit 1

STORE_ROOT=$( grep -E '^store-root' /etc/selinux/semanage.conf | tr -d ' ' | cut -d '=' -f 2 )
if [ -z "$STORE_ROOT" ]; then
    STORE_ROOT=/var/lib/selinux
fi

clean_nfs() {
        rlLog "Cleanup nfs mounts and mount points"
        rlRun "umount $STORE_ROOT"
        rlRun "systemctl disable nfs-server --now"
        rlRun "umount /srv/nfs/selinux"
        rlRun "rm -rf /srv"
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "pushd $tmp"
        rlRun "set -o pipefail"
        rlAssertRpm nfs-utils
        rlAssertRpm policycoreutils-python-utils
        rlRun "mkdir -p /srv/nfs/selinux"
        rlRun "cp -r $STORE_ROOT /srv/selinux"
        rlRun "mount --bind /srv/selinux /srv/nfs/selinux"
        rlRun "sed -i 's%.*rootdir.*=.*%rootdir=/srv/nfs%' /etc/nfs.conf"
        rlRun "systemctl enable nfs-server --now"
        rlRun "cat > /etc/exports <<EOF
/selinux *(rw,sync,no_root_squash)
EOF"
        rlRun "exportfs -a"
        rlRun "showmount -e 127.0.0.1"
        rlWatchdog 'mount 127.0.0.1:/selinux $STORE_ROOT' 15 KILL
        if ! mountpoint -q "$STORE_ROOT"; then
            clean_nfs
            rlDie "NFS mount did not finish successfully"
        fi
    rlPhaseEnd

    rlPhaseStartTest "semanage root on nfs"
        rlRun "semanage fcontext -a -e /home /tmp/testdir"
        rlRun "semanage fcontext -d -e /home /tmp/testdir"
    rlPhaseEnd

    rlPhaseStartCleanup
        clean_nfs
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
    rlPhaseEnd
rlJournalEnd
