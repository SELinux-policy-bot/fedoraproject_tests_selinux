#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/ladvd
#   Description: Test coverage for SELinux AVC issues related to ladvd service.
#   Author: Amith Kumar <apeetham@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-policy"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm ladvd
        rlAssertRpm ladvd-selinux
        rlServiceStop ladvd
        rlSESetEnforce
        rlSEStatus
    rlPhaseEnd

    rlPhaseStartTest "ladvd service selinux denials, bz#1834325"
        rlServiceStart ladvd
        sleep 2
        rlRun "ausearch -m AVC -c ladvd --raw > /tmp/avcfile" 1
        if grep "tclass=process2" /tmp/avcfile; then
            grep "tclass=process2" /tmp/avcfile > /tmp/avc_class_file
            rlAssertNotGrep "denied  { nnp_transition }" /tmp/avc_class_file
        else
            rlLog "AVCs related to tclass process2 not found."
        fi
        if grep "tclass=packet_socket" /tmp/avcfile; then
            grep "tclass=packet_socket" /tmp/avcfile > /tmp/avc_class_file
            rlAssertNotGrep "denied  { map }" /tmp/avc_class_file
        else
            rlLog "AVCs related to tclass packet_socket not found."
        fi
        rlSESearchRule "allow init_t ladvd_t : process2 { nnp_transition }"
        rlSESearchRule "allow ladvd_t ladvd_t : packet_socket { map }"
        rlSESearchRule "allow ladvd_t ladvd_t : capability { kill }"
        rlServiceStop ladvd
    rlPhaseEnd

    rlPhaseStartTest "ladvd selinux denials due to libpcap, bz#1855163"
        rlServiceStart ladvd
        sleep 2
        rlRun "ausearch -m AVC -c 'ladvd' --raw > /tmp/avcfile" 1
        if grep "tclass=netlink_rdma_socket" /tmp/avcfile; then
            grep "tclass=netlink_rdma_socket" /tmp/avcfile > /tmp/avc_class_file
            rlAssertNotGrep "denied  { create }" /tmp/avc_class_file
            rlAssertNotGrep "denied  { setopt }" /tmp/avc_class_file
            rlAssertNotGrep "denied  { bind }" /tmp/avc_class_file
            rlAssertNotGrep "denied  { getattr }" /tmp/avc_class_file
        else
            rlLog "AVCs related to tclass netlink_rdma_socket not found."
        fi
        rlSESearchRule "allow ladvd_t self : netlink_rdma_socket { bind create getattr setopt }"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlServiceRestore ladvd
        rlRun "rm -f /tmp/avcfile"
        rlRun "rm -f /tmp/avc_class_file"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
