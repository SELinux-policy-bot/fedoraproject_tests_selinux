#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libsemanage/Sanity/usepasswd-in-semanage-conf
#   Description: Make sure usepasswd option in semanage.conf works properly
#   Author: Vit Mojzis <vmojzis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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

PACKAGE="libsemanage"
SEMANAGE_CONF="/etc/selinux/semanage.conf"

rlJournalStart
	rlPhaseStartSetup
		rlAssertRpm ${PACKAGE}
		rlAssertRpm policycoreutils
		rlAssertRpm selinux-policy
		rlFileBackup ${SEMANAGE_CONF}
		rlRun "rpm -qf /usr/sbin/semanage"
		rlRun "grep -v -e '^#' -e '^$' ${SEMANAGE_CONF}"
		OUTPUT_FILE=`mktemp`
		CMP_FILE=`mktemp`
		rlRun "setenforce 1"
		rlRun "sestatus"
    rlPhaseEnd

	rlPhaseStartTest "usepasswd=False"
		rlRun 'sed -i "s|usepasswd=.*$|usepasswd=False|g" ${SEMANAGE_CONF}'
		rlRun 'semodule -B' # rebuild file_contexts.homedirs
		rlRun "semanage fcontext -l 2>&1 > ${CMP_FILE}" # save file contexts for comparison
		rlRun 'useradd -Z unconfined_u duck'
		rlRun 'semanage login -l | grep duck' 0
		rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}"
		rlRun "diff ${CMP_FILE} ${OUTPUT_FILE}" 0
	rlPhaseEnd

	rlPhaseStartTest "usepasswd=True"
		rlRun 'sed -i "s|usepasswd=.*$|usepasswd=True|g" ${SEMANAGE_CONF}'
		rlRun 'semodule -B' # rebuild file_contexts.homedirs
		rlRun "semanage fcontext -l 2>&1 > ${OUTPUT_FILE}" # file context with new selinux login
		rlRun 'semanage login -d duck'
		rlRun "semanage fcontext -l 2>&1 > ${CMP_FILE}"
		rlRun "diff ${CMP_FILE} ${OUTPUT_FILE} | grep duck"
	rlPhaseEnd

	rlPhaseStartCleanup
		rlRun "rm -f ${OUTPUT_FILE} ${CMP_FILE}"
		rlRun "userdel duck"
		rlFileRestore
	rlPhaseEnd
rlJournalPrintText
rlJournalEnd

