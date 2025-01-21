#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Sanity/systemd-generators
#   Description: Testing systemd system generators which are SELinux confined
#   Author: Zdenek Pytela <zpytela@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"
SD_SYSTEM_GENERATOR_PATH="/usr/lib/systemd/system-generators /usr/local/lib/systemd/system-generators /etc/systemd/system-generators /run/systemd/system-generators"
SD_SYSTEM_GENERATORS=""

# To make testing easier, systemd implements various tweaks into its services:
# - variables like SYSTEMD_FSTAB or SYSTEMD_PROC_CMDLINE can be used to point to files
#   which will be taken into account instead of the original ones
# - SYSTEMD_IN_INITRD=1 forges being executed in initial ramdisk
# - network generator accepts position arguments as proc-command-line entries
#   systemd-network-generator [OPTIONS...] [-- KERNEL_CMDLINE]

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    ### Information about the system (release, systemd and policy versions)
    rlPhaseStartTest "Display basic system information"
	rlRun "cat /etc/system-release"
	rlRun "uname -a"
	rlRun "rpm -qa \"systemd*\"|sort"
	rlRun "rpm -qa \"selinux-*\" \"*-selinux\" | sort"
    rlPhaseEnd

    ### Look for executables in the directories for systemd-system-generators
    rlPhaseStartTest "Find all generators"
    for dir in ${SD_SYSTEM_GENERATOR_PATH}; do
      [ -d "${dir}" ] || continue
      for file in ${dir}/*; do
	FILEPATH=$(realpath "${file}")
        [ "$?" = 0 ] || continue
        [ -x "$FILEPATH" ] || continue
	CONTEXT=$(stat -c"%C" "${FILEPATH}")
        [ "$?" = 0 ] || continue
	if [[ ${CONTEXT} =~ ":init_exec_t:" ]] || [[ ${CONTEXT} =~ ":lib_t:" ]] || [[ ${CONTEXT} =~ ":usr_t:" ]]
	then
	  SD_SYSTEM_GENERATORS_NOTCONFINED="${SD_SYSTEM_GENERATORS_NOTCONFINED} $FILEPATH"
	else
	  SD_SYSTEM_GENERATORS="${SD_SYSTEM_GENERATORS} $FILEPATH"
	fi
      done
    done
    echo "List of confined generators:"
    echo "${SD_SYSTEM_GENERATORS}"
    echo "List of non-confined generators:"
    echo "${SD_SYSTEM_GENERATORS_NOTCONFINED}"
    rlPhaseEnd

    if [ -f /usr/lib/systemd/system/systemd-networkd.service ] ; then

    ### network-generator actually is a service, not a generator
    # systemd-network-generator.service is a system service that translates ip= and the
    # related settings on the kernel command line (see below) into systemd.network(5),
    # systemd.netdev(5), and systemd.link(5) configuration files
    rlPhaseStartTest "systemd-network-generator"
	rlRun "systemd-run -u sdng-manual.service /usr/lib/systemd/systemd-network-generator -- nameserver=8.8.8.8 ip=dhcp"
	rlRun "journalctl -u sdng-manual.service"
	rlRun "systemctl restart systemd-networkd"
	rlRun "systemctl status systemd-networkd"
	rlRun "networkctl"
	rlRun "diff /run/systemd/network/71-default.network 71-default.network"
    rlPhaseEnd

    rlPhaseStartTest "systemd-network-generator: ip=off"
	rlRun "systemd-run -u sdng-manual-off.service /usr/lib/systemd/systemd-network-generator -- ip=off"
	rlRun "journalctl -u sdng-manual-off.service"
	rlRun "systemctl restart systemd-networkd"
	rlRun "systemctl status systemd-networkd"
	rlRun "networkctl"
	rlRun "diff /run/systemd/network/71-default.network 71-default-off.network"
    rlPhaseEnd

    fi

    ### fstab-generator
    # systemd-fstab-generator is a generator that translates /etc/fstab (see fstab(5)
    # for details) into native systemd units early at boot and when configuration of
    # the system manager is reloaded. This will instantiate mount and swap
    # units as necessary.

    # fstab-generator 1 - use /etc/fstab
    rlPhaseStartTest "systemd-fstab-generator /etc"
	rlFileBackup "/etc/fstab"
	rlRun "mkdir -p /newproc"
	echo "/proc /newproc none bind 0 0" >> /etc/fstab
	rlRun "SYSTEMD_LOG_LEVEL=debug systemd-run -u sdfg-manual.service /usr/lib/systemd/system-generators/systemd-fstab-generator /run/systemd/generator"
	rlRun "journalctl -u sdfg-manual.service"
	rlRun "systemctl daemon-reload"
	rlRun "systemctl start newproc.mount"
	rlRun "systemctl status newproc.mount"
	rlRun "ls -lZd /newproc/1"
	rlRun "systemctl stop newproc.mount"
    rlPhaseEnd

    # fstab-generator 2 - use a local fstab-like file
    rlPhaseStartTest "systemd-fstab-generator /tmp"
	echo "/dev/loop42 /mnt/loop ext4 defaults 0 0" >> /tmp/fstab
	rlRun "mkdir -p /mnt/loop"
	rlRun "chcon --reference /etc/fstab /tmp/fstab"
	rlRun "dd if=/dev/zero of=/tmp/loopfile bs=16M count=1"
	rlRun "chcon -t user_tmp_t /tmp/loopfile"
	rlRun "losetup /dev/loop42 /tmp/loopfile"
	rlRun "losetup -j /tmp/loopfile"
	rlRun "mkfs.ext4 /dev/loop42"
	rlRun "systemd-run -E SYSTEMD_FSTAB=/tmp/fstab -u sdfg-tmpfstab.service /usr/lib/systemd/system-generators/systemd-fstab-generator /run/systemd/generator"
	rlRun "diff /run/systemd/generator/mnt-loop.mount mnt-loop.mount"
	rlRun "ls -lZa /mnt/loop"
    rlPhaseEnd

    # fstab-generator 3: nfs

    ### gpt-generator
    #rlPhaseStartTest "systemd-gpt-generator"
    #rlPhaseEnd

    ### nfs-generator
    # 7a76dc1c4eba7a6cd3b59cdd40b6b4bd90312e07 needs to be reverted
    #rlPhaseStartTest "systemd-nfs-generator"
    #rlPhaseEnd

    ### systemd-rc-local-generator
    # systemd-rc-local-generator is a generator that checks whether /etc/rc.d/rc.local
    # exists and is executable, and if it is, pulls the rc-local.service unit into the
    # boot process.
    # the service unit file already exists: /usr/lib/systemd/system/rc-local.service
    rlPhaseStartTest "systemd-rc-local-generator"
	cat > /etc/rc.d/rc.local << EOF
#!/bin/bash
echo "This is a script to check rc-local generator."
EOF
	rlRun "chmod +x /etc/rc.d/rc.local"
	rlRun "restorecon -v /etc/rc.d/rc.local"
	rlRun "systemd-run -u sdrg-manual.service /usr/lib/systemd/system-generators/systemd-rc-local-generator /run/systemd/generator"
	rlRun "journalctl -u sdrg-manual.service"
	rlRun "systemctl daemon-reload"
	rlRun "systemctl start rc-local.service"
	rlRun "systemctl status rc-local.service"
	rlRun "systemctl stop rc-local.service"
    rlPhaseEnd

    ### sysv-generator
    # systemd-sysv-generator is a generator that creates wrapper .service units
    # for SysV init[1] scripts in /etc/init.d/* at boot and when configuration
    # of the system manager is reloaded.
    rlPhaseStartTest "systemd-sysv-generator"
	cat > /etc/rc.d/init.d/sysv-generator-test.sh << EOF
#!/bin/bash
echo "This is a script to check sysv generator."
EOF
	rlRun "chmod +x /etc/rc.d/init.d/sysv-generator-test.sh"
	rlRun "restorecon -Fv /etc/rc.d/init.d/sysv-generator-test.sh"
	rlRun "systemd-run -u sdsg-manual.service /usr/lib/systemd/system-generators/systemd-sysv-generator /run/systemd/generator /run/systemd/generator.early /run/systemd/generator.late"
	rlRun "journalctl -u sdsg-manual.service"
	rlRun "systemctl daemon-reload"
	rlRun "systemctl start sysv-generator-test.service"
	rlRun "systemctl status sysv-generator-test.service"
	rlRun "systemctl stop sysv-generator-test.service"
    rlPhaseEnd

    if rlIsCentOS 10 || rlIsRHEL 10 ; then
    rlPhaseStartTest "RHEL-72549"
        rlSEMatchPathCon "/usr/lib/systemd/system-generators/systemd-ssh-generator" "systemd_ssh_generator_exec_t"
        rlSEMatchPathCon "/dev/vsock" "vsock_device_t"
        rlSEMatchPathCon "/run/systemd/generator/sshd-vsock.socket" "systemd_unit_file_t"
        rlSESearchRule "allow init_t systemd_ssh_generator_exec_t : file { getattr open read execute } [ ]"
        rlSESearchRule "type_transition init_t systemd_ssh_generator_exec_t : process systemd_ssh_generator_t"
        rlSESearchRule "allow systemd_ssh_generator_t vsock_device_t : chr_file { getattr ioctl open read } [ ]"
        rlSESearchRule "allow systemd_ssh_generator_t systemd_unit_file_t : file { create getattr write open } [ ]"
    rlPhaseEnd
    fi

    ### generators from other packages: install them all?
    # dnf install "/usr/lib/systemd/system-generators/*"
    # cloud-init-generator nfs-server-generator rpc-pipefs-generator selinux-autorelabel-generator.sh zram-generator
    # cloud-init nfs-utils policycoreutils zram-generator

    ### selinux-autorelabel-generator
    # This systemd.generator(7) detects if SELinux is running and if the
    # user requested an autorelabel, and if so sets the default target to
    # selinux-autorelabel.target.
    rlPhaseStartTest "selinux-autorelabel-generator"
	rlFileBackup "/etc/selinux/config"
	rlRun "echo AUTORELABEL=0 >> /etc/selinux/config"
	rlRun "touch /.autorelabel"
	rlRun "SYSTEMD_LOG_LEVEL=debug systemd-run -u sdsa-manual.service /usr/lib/systemd/system-generators/selinux-autorelabel-generator.sh /run/systemd/generator /run/systemd/generator.early /run/systemd/generator.late"
	rlRun "journalctl -u sdsa-manual.service"
	rlRun "test \"$(readlink /run/systemd/generator.early/default.target)\" = \"/usr/lib/systemd/system/selinux-autorelabel.target\""
	rlRun "diff /run/systemd/generator.early/selinux-autorelabel.service.d/tty.conf tty.conf"
    rlPhaseEnd

    ### cleanup, restoring the previous content
    # re-run again all generators as an effect of daemon-reload;
    # changes which used special systemd variables will go away
    rlPhaseStartCleanup
        sleep 2
	rlRun "rmdir /mnt/loop"
	rlRun "losetup -d /dev/loop42"
	rlRun "/bin/rm /tmp/loopfile"
        rlFileRestore
	# fixme: remove non-natural generators
	rlRun "systemctl daemon-reload"
        rlSECheckAVC
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd
