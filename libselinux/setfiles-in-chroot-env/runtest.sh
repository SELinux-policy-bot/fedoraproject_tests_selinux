#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libselinux/Regression/setfiles-in-chroot-env
#   Description: Does setfiles work correctly in chroot environment?
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="libselinux"
CHROOT_DIR=`mktemp -d`
INSTALL_OPTION=""
if yum --help | grep -q use-host-config ; then
    INSTALL_OPTION="${INSTALL_OPTION} --use-host-config"
fi
if yum install --help | grep -q skip-broken ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-broken"
fi
if yum install --help | grep -q skip-unavailable ; then
    INSTALL_OPTION="${INSTALL_OPTION} --skip-unavailable"
fi

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm policycoreutils
    rlPhaseEnd

    rlPhaseStartTest "bz#2094683"
        rlRun "yum -y install filesystem policycoreutils selinux-policy-targeted --installroot=${CHROOT_DIR} ${INSTALL_OPTION}"
        rlRun "cp ./test-script.sh ${CHROOT_DIR}/usr/bin/"
        rlRun -s "chroot ${CHROOT_DIR} /usr/bin/test-script.sh"
        rlRun "grep -i -e 'no such file or directory' -e 'not set context' $rlRun_LOG" 1
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf ${CHROOT_DIR}"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

