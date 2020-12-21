#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libsemanage/Sanity/usepasswd-in-semanage-conf
#   Description: Make sure usepasswd option in semanage.conf works properly
#   Author: Vit Mojzis <vmojzis@redhat.com>
#   Author: Petr Lautrbach <plautrba@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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

PACKAGE="libsemanage"
SEMANAGE_CONF="/etc/selinux/semanage.conf"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm policycoreutils
        rlAssertRpm selinux-policy
        rlRun "rpm -qf /usr/sbin/semanage"
        rlRun "grep -v -e '^#' -e '^$' ${SEMANAGE_CONF}"
        OUTPUT_FILE=`mktemp`
        CMP_FILE=`mktemp`
        rlRun "setenforce 1"
        rlRun "sestatus"
    rlPhaseEnd

    # usepasswd=False - generate contexts for user with explicit SELinux mapping
    rlPhaseStartTest "usepasswd=False"
        rlFileBackup ${SEMANAGE_CONF}

        rlRun "sed -i 's|usepasswd=.*$|usepasswd=False|g' ${SEMANAGE_CONF}"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${CMP_FILE}" # save file contexts for comparison

        rlLog "Standard users should not trigger a policy change"
        rlRun "useradd duck-home"
        rlRun "useradd -d /tmp duck-tmp"
        rlRun "useradd -d /var/lib/duck duck-var-lib"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE}" 0
        rlRun "userdel duck-home"
        rlRun "userdel duck-tmp"
        rlRun "userdel duck-var-lib"

        rlLog "SELinux users with home in / shoud not trigger a policy change"
        rlRun "useradd -Z unconfined_u -d /tmp duck-tmp"
        rlRun "useradd -Z unconfined_u -d /var duck-var"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE}" 0
        rlRun "userdel -Z duck-tmp"
        rlRun "userdel -Z duck-var"

        rlLog "Other SELinux users should trigger a policy change"
        rlRun "useradd -Z unconfined_u duck-home"
        rlRun "useradd -Z unconfined_u -d /var/home duck-var-home"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE} | grep -E 'duck-(home|var-home)'" 0
        rlRun "userdel -Z duck-home"
        rlRun "userdel -Z duck-var-home"

        rlFileRestore
    rlPhaseEnd

    rlPhaseStartTest "usepasswd=True"
        rlFileBackup ${SEMANAGE_CONF}

        rlRun "sed -i 's|usepasswd=.*$|usepasswd=True|g' ${SEMANAGE_CONF}"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${CMP_FILE}" # save file contexts for comparison

        rlLog "Standard users with home in /home should not trigger a policy change"
        rlRun "useradd duck-home"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE}" 0
        rlRun "userdel duck-home"

        rlLog "Standard users with home in directory like /var/home should trigger a policy change"
        rlRun "useradd -d /var/home/duck duck-var-home"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE} | grep -E '/var/home/'" 0
        rlRun "userdel duck-var-home"

        rlLog "Standard users with home in / shoud not trigger a policy change"
        rlRun "useradd -d /tmp duck-tmp"
        rlRun "useradd -d /var duck-var"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE}" 0
        rlRun "userdel -Z duck-tmp"
        rlRun "userdel -Z duck-var"

        rlLog "SELinux users with home in / shoud not trigger a policy change"
        rlRun "useradd -Z unconfined_u -d /tmp duck-tmp"
        rlRun "useradd -Z unconfined_u -d /var duck-var"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE}" 0
        rlRun "userdel -Z duck-tmp"
        rlRun "userdel -Z duck-var"

        rlLog "Other SELinux users should trigger a policy change"
        rlRun "useradd -Z unconfined_u duck-home"
        rlRun "useradd -Z unconfined_u -d /var/home duck-var-home"
        rlRun "semodule -B" # rebuild file_contexts.homedirs
        rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
        rlRun "diff -u ${CMP_FILE} ${OUTPUT_FILE} | grep -E 'duck-(home|var-home)'" 0
        rlRun "userdel -Z duck-home"
        rlRun "userdel -Z duck-var-home"

        rlFileRestore
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f ${OUTPUT_FILE} ${CMP_FILE}"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

