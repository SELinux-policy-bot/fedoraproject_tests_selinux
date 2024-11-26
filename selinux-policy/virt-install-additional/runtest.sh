#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/virt-install-additional
#   Description: SELinux interferes with virt-install and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm virt-install

        rlRun "yum -y install libvirt\* qemu\* --skip-broken"

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65038"
        rlSESearchRule "allow virtqemud_t svirt_tcg_t : lnk_file { read } [ ]"
        rlSESearchRule "allow virtqemud_t svirt_tcg_t : process { getrlimit } [ ]"
        rlSESearchRule "allow virtqemud_t svirt_t : process { getrlimit } [ ]"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --disk none --wait 0 --name test1 --cpu mode=maximum,check=none,migratable=on,numa.cell.id=0,numa.cell.cpus=0,numa.cell.memory=512000,numa.cell.unit="KiB" --memory maxMemory.slots=16,maxMemory=4096"
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test1.*running'"
        rlRun "virsh attach-device test1 dimm.xml"
        sleep 30
        rlRun "virsh destroy test1"
        rlRun "virsh undefine test1"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65373"
        rlSESearchRule "allow virtqemud_t virtqemud_t : tun_socket { relabelto relabelfrom } [ ]"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test2 --network type=network,mac.address='52:54:00:ee:01:68',source=default,model.type=virtio,driver.queues=4"
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test2.*running'"
        rlRun "virsh destroy test2"
        rlRun "virsh undefine test2"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65383"
        rlSESearchRule "allow virtqemud_t sysfs_t : file { write } [ ]"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test3 --network type=network,mac.address='52:54:00:23:f2:12',source=default,model.type=virtio --xml xpath.set=./devices/interface/port/@isolated=yes"
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test3.*running'"
        rlRun "virsh destroy test3"
        rlRun "virsh undefine test3"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65789"
        rlSESearchRule "allow virtqemud_t numad_exec_t : file { getattr open read map execute } [ ]"
        rlSESearchRule "allow virtqemud_t numad_t : process { transition } [ ]"
        rlSESearchRule "type_transition virtqemud_t numad_exec_t : process numad_t"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test4 --numatune memory.mode='strict',memory.placement='auto'"
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test4.*running'"
        rlRun "virsh destroy test4"
        rlRun "virsh undefine test4"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-56029 + RHEL-69118"
        if rlIsRHEL 9 || rlIsCentOS 9 ; then
            rlSESearchRule "allow virtd_t nbdkit_exec_t : file { entrypoint } [ ]"
        elif rlIsRHEL 10 || rlIsCentOS 10 ; then
            rlSESearchRule "allow virtqemud_t nbdkit_exec_t : file { getattr open read map execute } [ ]"
            rlSESearchRule "allow virtqemud_t nbdkit_t : process { transition } [ ]"
            rlSESearchRule "type_transition virtqemud_t nbdkit_exec_t : process nbdkit_t"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlFileBackup /etc/libvirt/qemu.conf
        rlRun "sed -i 's/^.*storage_use_nbdkit.*=.*$/storage_use_nbdkit = 1/' /etc/libvirt/qemu.conf"
        rlRun "grep storage_use_nbdkit /etc/libvirt/qemu.conf"
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --disk source.protocol=ssh,source.name=/var/lib/libvirt/images/test.img,source.host0.name=10.73.210.25,source.host0.port=22 --wait 0 --name test5"
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test5.*running'"
        rlRun "virsh destroy test5"
        rlRun "virsh undefine test5"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

