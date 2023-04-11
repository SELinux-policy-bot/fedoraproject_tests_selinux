#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/mcstrans/Regression/mcstrans-daemon-segfaults-when-using-secon-C
#   Description: mcstrans daemon segfaults when secon -C asks for incomplete context
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
if rlIsRHEL 6 ; then
    SERVICE_NAME="mcstrans"
else # RHEL-7 and above
    SERVICE_NAME="mcstransd"
fi
if rlIsRHEL 6 7 ; then
    if which python3 >& /dev/null ; then
        PYTHON="python3"
    else
        PYTHON="python2"
    fi
else # RHEL-8
    if which python3 >& /dev/null ; then
        PYTHON="python3"
    else
        PYTHON="/usr/libexec/platform-python"
    fi
fi

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm policycoreutils
        rlAssertRpm selinux-policy-targeted
        rlServiceStop ${SERVICE_NAME}
        rlFileBackup /etc/selinux/targeted/secolor.conf
    rlPhaseEnd

    rlPhaseStartTest "bz#1315996 + bz#1316680 + bz#1699784"
        rlRun "dmesg > before-secon-C.txt"
        rlRun "cp -f secolor.conf /etc/selinux/targeted/"
        for CONTEXT in ":::" "xyz_u:xyz_r:xyz_t:" "user_u:" "user_u:user_r:" "user_u:user_r:user_t:" ; do
            rlRun "service ${SERVICE_NAME} restart"
            sleep 1
            rlRun "service ${SERVICE_NAME} status"
            set -x
            echo -en "import selinux\nselinux.selinux_raw_context_to_color(\"${CONTEXT}\")\n" | ${PYTHON}
            set +x
            # rlRun "secon -C ${CONTEXT}" 0,1
            sleep 1
            rlRun "service ${SERVICE_NAME} status"
        done
        rlRun "dmesg > after-secon-C.txt"
        rlRun "diff before-secon-C.txt after-secon-C.txt | grep \"mcstransd.*segfault\"" 1
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f before-secon-C.txt after-secon-C.txt"
        rlRun "rm -f /etc/selinux/targeted/secolor.conf"
        rlFileRestore
        rlServiceRestore ${SERVICE_NAME}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

