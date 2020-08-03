#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

# Optional path to a script that will be sourced in the Install phase.
# Can be used to set up Ceph repos on RHEL-8.
INSTALL_SCRIPTLET="${INSTALL_SCRIPTLET:-/dev/null}"

function check_config() {
    [ -f "/lib/modules/$(uname -r)/config" ] && \
        grep -q "^CONFIG_CEPH_FS_SECURITY_LABEL=y\$" "/lib/modules/$(uname -r)/config"
}

function get_file_con() {
    getfattr -h --absolute-names --only-values -n security.selinux "$1" | tr -d '\000'
}

function strip_mls() {
    # strip the MLS -- mcstrans might be running, leading to different MLS
    # fields than expected
    sed 's/\([^:]*:[^:]*:[^:]*\):.*$/\1/g'
}

function check_file_con() {
    rlAssertEquals "Check expected context of $1" \
        "$(get_file_con "$1" | strip_mls)" \
        "$(echo "$2" | strip_mls)"
}

function rlIsEL() {
    rlIsRHEL "$@" || rlIsCentOS "$@"
}

rlJournalStart
    source "$INSTALL_SCRIPTLET"

    rlPhaseStartSetup
        HOSTNAME="$(hostname)"

        rlRun "pip3 install --user ceph-deploy"
        rlRun "export PATH=\"\$HOME/.local/bin:\$PATH\""
        if rlIsFedora '>=32'; then
            # work around Python 3.8 deprecated functions until this is resolved:
            # https://tracker.ceph.com/issues/44849
            rlRun "sed -i '/linux_distribution = /d;s/linux_distribution()/(\"Fedora\", \"32\", \"Thirty Two\")/' \"\$HOME\"/.local/lib/*/site-packages/ceph_deploy/hosts/remotes.py"
        fi

        if ! [ -f "$HOME/.ssh/id_rsa.pub" ]; then
            rlRun "rm -f \"\$HOME/.ssh/id_rsa\""
            rlRun "cat /dev/zero | ssh-keygen -q -N '' >/dev/null"
        fi
        rlRun "cat \"\$HOME/.ssh/id_rsa.pub\" >> \"\$HOME/.ssh/authorized_keys\""
        rlRun "ssh -o 'StrictHostKeyChecking no' \$USER@$HOSTNAME true"

        rlRun "tmpdir=\"\$(mktemp -d)\""
        rlRun "pushd \"\$tmpdir\""
        rlRun "ceph-deploy new $HOSTNAME"
        rlRun "echo 'osd crush chooseleaf type = 0' >> ceph.conf"
        rlRun "echo 'osd pool default size = 1' >> ceph.conf"
        rlRun "echo 'mon allow pool delete = true' >> ceph.conf"

        rlRun "ceph-deploy --overwrite-conf mon create $HOSTNAME"
        rlRun "ceph-deploy gatherkeys $HOSTNAME"
        rlRun "ceph-deploy mgr create $HOSTNAME"
        rlRun "ceph-deploy mds create $HOSTNAME"
        rlRun "cp ceph.client.admin.keyring /etc/ceph/"

        rlRun "UUID=\$(uuidgen)"
        rlRun "OSD_SECRET=\$(ceph-authtool --gen-print-key)"
        rlRun "cp ceph.bootstrap-osd.keyring  /var/lib/ceph/bootstrap-osd/ceph.keyring"
        rlRun "ID=\$(echo \"{\\\"cephx_secret\\\": \\\"\$OSD_SECRET\\\"}\" | ceph osd new \$UUID -i -  -n client.bootstrap-osd -k /var/lib/ceph/bootstrap-osd/ceph.keyring)"
        rlRun "mkdir /var/lib/ceph/osd/ceph-\$ID"
        rlRun "ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-\$ID/keyring --name osd.\$ID --add-key \$OSD_SECRET"
        rlRun "ceph-osd -i \$ID --mkfs --osd-uuid \$UUID"
        rlRun "chown -R ceph:ceph /var/lib/ceph/osd/ceph-\$ID"
        rlRun "systemctl enable ceph-osd@\$ID"
        rlRun "systemctl start ceph-osd@\$ID"

        rlRun "ceph osd pool create cephfs_data 64"
        rlRun "ceph osd pool create cephfs_metadata 64"

        rlRun "ceph fs new cephfs cephfs_metadata cephfs_data"

        rlLog "Waiting for pools to become active..."
        for (( i = 0; i < 30; i++ )); do
            ceph mds stat | grep -q '=up:active' && break
            sleep 0.5s
        done
        rlRun "ceph mds stat | grep '=up:active'"
        rlRun "ceph fs ls"
        rlRun "ceph -s"

        rlRun "SECRET=\"\$(ceph auth print-key client.admin)\""
        rlRun "mkdir -p /mnt/myceph"
        rlRun "mount -t ceph $HOSTNAME:6789:/ /mnt/myceph -o name=admin,secret=\$SECRET"
    rlPhaseEnd

    rlPhaseStartTest
        SEUSER="$(id -Z | cut -d ':' -f 1)"

        if rlIsFedora '>=32'; then
            # F32 and above - full xattr handling
            # See: https://github.com/fedora-selinux/selinux-policy/pull/289
            rlRun "check_config" 0 "Check if kernel support is present"
            check_file_con "/mnt/myceph" "system_u:object_r:unlabeled_t:s0"
            rlRun "mkdir /mnt/myceph/test"
            check_file_con "/mnt/myceph/test" "$SEUSER:object_r:unlabeled_t:s0"
            rlRun "chcon system_u:object_r:usr_t:s0 /mnt/myceph/test"
            check_file_con "/mnt/myceph/test" "system_u:object_r:usr_t:s0"

            rlRun "touch /mnt/myceph/test/file"
            rlRun "mkdir /mnt/myceph/test/dir"
            rlRun "ln -s /etc /mnt/myceph/test/symlink"
            rlRun "mknod /mnt/myceph/test/fifo p"
            rlRun "mknod /mnt/myceph/test/block b 1 3"
            rlRun "mknod /mnt/myceph/test/char c 1 3"

            check_file_con "/mnt/myceph/test/file" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/dir" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/symlink" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/fifo" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/block" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/char" "$SEUSER:object_r:usr_t:s0"
        elif rlIsEL '>=8.3'; then
            # RHEL-8 - genfscon + xattr handling
            # See: https://bugzilla.redhat.com/show_bug.cgi?id=1823764
            # and: https://bugzilla.redhat.com/show_bug.cgi?id=1814689
            rlRun "check_config" 0 "Check if kernel support is present"
            check_file_con "/mnt/myceph" "system_u:object_r:cephfs_t:s0"
            rlRun "mkdir /mnt/myceph/test"
            check_file_con "/mnt/myceph/test" "$SEUSER:object_r:cephfs_t:s0"
            rlRun "chcon system_u:object_r:usr_t:s0 /mnt/myceph/test"
            check_file_con "/mnt/myceph/test" "system_u:object_r:usr_t:s0"

            rlRun "touch /mnt/myceph/test/file"
            rlRun "mkdir /mnt/myceph/test/dir"
            rlRun "ln -s /etc /mnt/myceph/test/symlink"
            rlRun "mknod /mnt/myceph/test/fifo p"
            rlRun "mknod /mnt/myceph/test/block b 1 3"
            rlRun "mknod /mnt/myceph/test/char c 1 3"

            check_file_con "/mnt/myceph/test/file" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/dir" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/symlink" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/fifo" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/block" "$SEUSER:object_r:usr_t:s0"
            check_file_con "/mnt/myceph/test/char" "$SEUSER:object_r:usr_t:s0"
        else
            # F31 and below - just genfscon
            check_file_con "/mnt/myceph" "system_u:object_r:cephfs_t:s0"
            rlRun "mkdir /mnt/myceph/test"
            check_file_con "/mnt/myceph/test" "system_u:object_r:cephfs_t:s0"
            rlRun "chcon system_u:object_r:usr_t:s0 /mnt/myceph/test" 1
            check_file_con "/mnt/myceph/test" "system_u:object_r:cephfs_t:s0"

            rlRun "touch /mnt/myceph/test/file"
            rlRun "mkdir /mnt/myceph/test/dir"
            rlRun "ln -s /etc /mnt/myceph/test/symlink"
            rlRun "mknod /mnt/myceph/test/fifo p"
            rlRun "mknod /mnt/myceph/test/block b 1 3"
            rlRun "mknod /mnt/myceph/test/char c 1 3"

            check_file_con "/mnt/myceph/test/file" "system_u:object_r:cephfs_t:s0"
            check_file_con "/mnt/myceph/test/dir" "system_u:object_r:cephfs_t:s0"
            check_file_con "/mnt/myceph/test/symlink" "system_u:object_r:cephfs_t:s0"
            check_file_con "/mnt/myceph/test/fifo" "system_u:object_r:cephfs_t:s0"
            check_file_con "/mnt/myceph/test/block" "system_u:object_r:cephfs_t:s0"
            check_file_con "/mnt/myceph/test/char" "system_u:object_r:cephfs_t:s0"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "umount /mnt/myceph" 0-255
        rlRun "rm -rf /mnt/myceph"

        rlRun "systemctl stop ceph-mds@*"
        rlRun "ceph fs rm cephfs --yes-i-really-mean-it"
        rlRun "ceph osd pool delete cephfs_data cephfs_data --yes-i-really-really-mean-it"
        rlRun "ceph osd pool delete cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it"
        rlRun "ceph osd down \$ID"
        rlRun "ceph osd rm \$ID"
        rlRun "ceph auth del osd.\$ID"
        rlRun "systemctl stop ceph-osd@*"
        rlRun "systemctl stop ceph-mon@*"
        rlRun "systemctl stop ceph-mgr@*"
        rlRun "rm -rf /var/lib/ceph/osd/ceph-$ID"

        rlRun "rm -rf \"\$tmpdir\""
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
