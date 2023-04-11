#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/mcstrans/Sanity/internal-examples-testsuite
#   Description: Wrapper for internal examples used as testsuite
#   Author: Milos Malik <mmalik@redhat.com>
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="mcstrans"
if rlIsRHEL 5 6 ; then
    SERVICE_NAME="mcstrans"
else
    SERVICE_NAME="mcstransd"
fi

if rlIsRHEL 5 6 7 ; then
    PYTHON="python2"
    SERVICE_START_LIMIT="[Service]
StartLimitIntervalSec=0
StartLimitBurst=50
"
else
    PYTHON="python3"
    SERVICE_START_LIMIT="[Unit]
StartLimitIntervalSec=0
"
fi

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm selinux-policy-targeted
        rlRun "mkdir -p /etc/systemd/system/mcstrans.service.d/"
        rlRun "mkdir -p /etc/systemd/system/mcstransd.service.d/"
        echo "${SERVICE_START_LIMIT}" > /etc/systemd/system/mcstrans.service.d/limit.conf
        rlRun "cp /etc/systemd/system/mcstrans.service.d/limit.conf /etc/systemd/system/mcstransd.service.d/limit.conf"
        rlRun "systemctl daemon-reload"
        rlServiceStop ${SERVICE_NAME}
        rlRun "mkdir -p /etc/selinux/targeted/setrans.d"
        rlFileBackup /etc/selinux/targeted/secolor.conf
        rlFileBackup /etc/selinux/targeted/setrans.conf
        rlFileBackup /usr/share/mcstrans/util/mlscolor-test
        rlFileBackup /usr/share/mcstrans/util/mlstrans-test
        rlRun "sed -i 's/^verbose.*$/verbose=1/' /usr/share/mcstrans/util/mlscolor-test"
        rlRun "sed -i 's/^verbose.*$/verbose=1/' /usr/share/mcstrans/util/mlstrans-test"
        if ! rlIsRHEL 5 6 7 && ! rlIsFedora ; then
            # convert the python2 scripts to python3 syntax
            rlRun "2to3 -w --no-diffs /usr/share/mcstrans/util/mlscolor-test"
            rlRun "2to3 -w --no-diffs /usr/share/mcstrans/util/mlstrans-test"
        fi
    rlPhaseEnd

    rlPhaseStartTest "default"
        rlRun "pushd /usr/share/mcstrans/examples/default"
        rlRun "rm -f /etc/selinux/targeted/secolor.conf"
        rlRun "cp -f setrans.conf /etc/selinux/targeted/setrans.conf"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlstrans-test default.test"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "include"
        rlRun "pushd /usr/share/mcstrans/examples/include"
        rlRun "rm -f /etc/selinux/targeted/secolor.conf"
        rlRun "cp -f setrans.conf /etc/selinux/targeted/setrans.conf"
        rlRun "sed -i 's/mls/targeted/' /etc/selinux/targeted/setrans.conf"
        rlRun "cp -f setrans.d/*  /etc/selinux/targeted/setrans.d"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlstrans-test default.test"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "non-mls-color"
        rlRun "pushd /usr/share/mcstrans/examples/non-mls-color"
        rlRun "cp -f secolor.conf /etc/selinux/targeted/secolor.conf"
        rlRun "rm -f /etc/selinux/targeted/setrans.conf"
        rlRun "touch /etc/selinux/targeted/setrans.conf"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlscolor-test non-mls.color"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "urcsts"
        rlRun "pushd /usr/share/mcstrans/examples/urcsts"
        rlRun "cp -f secolor.conf /etc/selinux/targeted/secolor.conf"
        rlRun "cp -f setrans.conf /etc/selinux/targeted/setrans.conf"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        #rlRun "${PYTHON} /usr/share/mcstrans/util/mlscolor-test urcsts.color"
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlstrans-test urcsts.test"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "urcsts-via-include"
        rlRun "pushd /usr/share/mcstrans/examples/urcsts-via-include"
        rlRun "cp -f secolor.conf /etc/selinux/targeted/secolor.conf"
        rlRun "cp -f setrans.conf /etc/selinux/targeted/setrans.conf"
        rlRun "sed -i 's/mls/targeted/' /etc/selinux/targeted/setrans.conf"
        rlRun "rm -f /etc/selinux/targeted/setrans.d/*"
        rlRun "cp setrans.d/* /etc/selinux/targeted/setrans.d"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        #rlRun "${PYTHON} /usr/share/mcstrans/util/mlscolor-test urcsts.color"
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlstrans-test urcsts.test"
        rlRun "popd"
    rlPhaseEnd

    if ! rlIsRHEL 5 6 ; then
    rlPhaseStartTest "nato"
        rlRun "pushd /usr/share/mcstrans/examples/nato"
        rlRun "rm -f /etc/selinux/targeted/secolor.conf"
        rlRun "cp -f setrans.conf /etc/selinux/targeted/setrans.conf"
        rlRun "sed -i 's/mls/targeted/' /etc/selinux/targeted/setrans.conf"
        rlRun "rm -f /etc/selinux/targeted/setrans.d/*"
        rlRun "cp setrans.d/* /etc/selinux/targeted/setrans.d"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        ${PYTHON} /usr/share/mcstrans/util/mlstrans-test nato.test
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlstrans-test nato.test"
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "pipes"
        rlRun "pushd /usr/share/mcstrans/examples/pipes"
        rlRun "rm -f /etc/selinux/targeted/secolor.conf"
        rlRun "cp -f setrans.conf /etc/selinux/targeted/setrans.conf"
        rlRun "sed -i 's/mls/targeted/' /etc/selinux/targeted/setrans.conf"
        rlRun "rm -f /etc/selinux/targeted/setrans.d/*"
        rlRun "cp setrans.d/* /etc/selinux/targeted/setrans.d"
        rlRun "service ${SERVICE_NAME} restart"
        sleep 1
        rlRun "service ${SERVICE_NAME} status"
        ${PYTHON} /usr/share/mcstrans/util/mlstrans-test pipes.test
        rlRun "${PYTHON} /usr/share/mcstrans/util/mlstrans-test pipes.test"
        rlRun "popd"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rlRun "rm -rf /etc/systemd/system/mcstrans.service.d/"
        rlRun "rm -rf /etc/systemd/system/mcstransd.service.d/"
        rlRun "rm -f /etc/selinux/targeted/secolor.conf /etc/selinux/targeted/setrans.conf"
        rlRun "rm -rf /etc/selinux/targeted/setrans.d"
        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

