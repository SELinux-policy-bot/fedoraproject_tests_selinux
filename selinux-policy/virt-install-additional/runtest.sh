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
        rlRun "rlImport 'selinux-policy/common'" 0,1
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
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t svirt_tcg_t : lnk_file { read } [ ]"
            rlSESearchRule "allow virtqemud_t svirt_tcg_t : process { getrlimit } [ ]"
            rlSESearchRule "allow virtqemud_t svirt_t : process { getrlimit } [ ]"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --disk none --wait 0 --name test1 --cpu mode=maximum,check=none,migratable=on,numa.cell.id=0,numa.cell.cpus=0,numa.cell.memory=512000,numa.cell.unit="KiB" --memory maxMemory.slots=16,maxMemory=4096" 0,1
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test1.*running'"
        rlWatchdog "virsh attach-device test1 dimm.xml" 30
        sleep 10
        rlRun "virsh destroy test1"
        rlRun "virsh undefine test1" 0,1
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65373"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t virtqemud_t : tun_socket { relabelto relabelfrom } [ ]"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test2 --network type=network,mac.address='52:54:00:ee:01:68',source=default,model.type=virtio,driver.queues=4" 0,1
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test2.*running'"
        rlRun "virsh destroy test2"
        rlRun "virsh undefine test2" 0,1
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65383"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t sysfs_t : file { write } [ ]"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test3 --network type=network,mac.address='52:54:00:23:f2:12',source=default,model.type=virtio --xml xpath.set=./devices/interface/port/@isolated=yes" 0,1
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test3.*running'"
        rlRun "virsh destroy test3"
        rlRun "virsh undefine test3" 0,1
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65789"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t numad_exec_t : file { getattr open read map execute } [ ]"
            rlSESearchRule "allow virtqemud_t numad_t : process { transition } [ ]"
            rlSESearchRule "type_transition virtqemud_t numad_exec_t : process numad_t"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test4 --numatune memory.mode='strict',memory.placement='auto'" 0,1
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test4.*running'"
        rlRun "virsh destroy test4"
        rlRun "virsh undefine test4" 0,1
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
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --disk source.protocol=ssh,source.name=/var/lib/libvirt/images/test.img,source.host0.name=localhost,source.host0.port=22 --wait 0 --name test5" 0,1
        sleep 30
        rlRun "virsh list"
        rlRun "virsh list | grep 'test5.*running'"
        rlRun "virsh destroy test5"
        rlRun "virsh undefine test5" 0,1
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
        rlFileRestore
    rlPhaseEnd

    rlPhaseStartTest "RHEL-69920"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t svirt_t : process { getsched } [ ]"
            rlSESearchRule "allow virtqemud_t svirt_tcg_t : process { getsched } [ ]"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test6" 0,1
        sleep 30
        rlRun "virsh vcpuinfo test6"
        rlRun "virsh list"
        rlRun "virsh list | grep 'test6.*running'"
        rlRun "virsh destroy test6"
        rlRun "virsh undefine test6" 0,1
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-74230"
        rlSEMatchPathCon "/dev/bus/usb/001/001" "usb_device_t"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t usb_device_t : chr_file { getattr } [ ]"
            rlSESearchRule "allow virtqemud_t usb_device_t : chr_file { open read write lock setattr } [ virt_use_usb ]"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "service virtnodedevd start"
        rlRun "lsusb -t"
        # USB devices may not be available
        rlRun "virsh nodedev-list | grep usb" 0,1
        for USB_ID in `virsh nodedev-list | grep usb` ; do
            rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test-${USB_ID} --host-device ${USB_ID}" 0,1
        done
        sleep 10
        rlRun "virsh list"
        for VM_NAME in `virsh list --name` ; do
            rlRun "virsh destroy ${VM_NAME}"
            rlRun "virsh undefine ${VM_NAME}" 0,1
        done
        rlRun "service virtnodedevd stop"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartTest "RHEL-76104"
        rlSEMatchPathCon "/dev/sg0" "scsi_generic_device_t"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t scsi_generic_device_t : chr_file { getattr open read write lock setattr } [ ]"
        fi
        rlRun "modprobe scsi_debug ptype=5"
        sleep 2
        rlRun "lsscsi -gs"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "service virtstoraged start"
        rlRun "service virtnodedevd start"
        # SCSI devices may not be available
        rlRun "virsh nodedev-list | grep scsi" 0,1
        for SCSI_ID in `virsh nodedev-list | grep scsi` ; do
            rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --wait 0 --name test-${SCSI_ID} --host-device ${SCSI_ID}" 0,1
        done
        sleep 10
        rlRun "virsh list"
        for VM_NAME in `virsh list --name` ; do
            rlRun "virsh destroy ${VM_NAME}"
            rlRun "virsh undefine ${VM_NAME}" 0,1
        done
        rlRun "service virtnodedevd stop"
        rlRun "service virtstoraged stop"
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
        rlRun "modprobe -r scsi_debug"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65266"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t sysfs_t : file { write } [ ]"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnodedevd start"
        rlRun "mkdir -p devices"
        rlRun "pushd devices"
        rlRun "virsh nodedev-list"
        for I in `virsh nodedev-list` ; do
            rlRun "virsh nodedev-dumpxml $I > $I"
        done
        if grep balloon * ; then
            J=`grep -l balloon *`
            rlRun "virsh nodedev-reattach $J"
        else
            rlLog "no balloon device was found - cannot reattach it"
        fi
        rlRun "popd"
        rlRun "rm -rf devices"
        sleep 2
        rlRun "service virtnodedevd stop"
        rlRun "service virtqemud stop"
    rlPhaseEnd

    rlPhaseStartTest "RHEL-65385"
        if seinfo -a | grep -q virt_driver_domain ; then
            rlSESearchRule "allow virtqemud_t sysfs_t : file { write } [ ]"
        fi
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd start"
        fi
        rlRun "service virtqemud start"
        rlRun "service virtnetworkd start"
        rlRun "virsh net-list"
        rlRun "virsh net-dumpxml default > default.xml"
        rlRun "virsh net-destroy default"
        rlRun "virsh net-undefine default"
        rlRun "sed -i \"s/^\(.*bridge\) \(.*\)$/\1 macTableManager='libvirt' \2/\" default.xml"
        rlRun "virsh net-create ./default.xml"
        sleep 2
        rlRun "virsh net-list"
        rlRun "virt-install --memory 128 --pxe --virt-type qemu --os-variant alpinelinux3.8 --disk none --wait 0 --name test7" 0,1
        sleep 10
        rlRun "virsh list"
        rlRun "virsh list | grep 'test7.*running'"
        rlRun "virsh destroy test7"
        rlRun "virsh undefine test7" 0,1
        rlRun "service virtnetworkd stop"
        rlRun "service virtqemud stop"
        if rlIsRHEL 8 ; then
            rlRun "service libvirtd stop"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

