#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/virtualization-daemons
#   Description: Various virtualization daemons are confined by SELinux
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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
ROOT_PASSWORD="redhat"
SERVICE_NAMES="libvirtd virtinterfaced virtlockd virtlogd virtlxcd virtnetworkd virtnodedevd virtnwfilterd virtproxyd virtqemud virtsecretd virtstoraged virtvboxd virtxend"
ALL_TUPLES="libvirtd:libvirtd:virtd_t \
            virtinterfaced:virtinterfaced:virtd_t \
            virtlockd:virtlockd:virtlogd_t \
            virtlogd:virtlogd:virtlogd_t \
            virtlxcd:virtlxcd:virtd_t \
            virtnetworkd:virtnetworkd:virtd_t \
            virtnodedevd:virtnodedevd:virtd_t \
            virtnwfilterd:virtnwfilterd:virtd_t \
            virtproxyd:virtproxyd:virtd_t \
            virtqemud:virtqemud:virtd_t \
            virtsecretd:virtsecretd:virtd_t \
            virtstoraged:virtstoraged:virtd_t \
            virtvboxd:virtvboxd:virtd_t"
#            virtxend:virtxend:virtd_t

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qa libvirt\*"

        rlRun "sed -i 's/^.*task.*never.*$//' /etc/audit/rules.d/audit.rules"
        rlRun "echo '-w /etc/shadow -p w' >> /etc/audit/rules.d/audit.rules"
        rlRun "service auditd restart"

        rlServiceStop ${SERVICE_NAMES}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
        rlSEMatchPathCon "/usr/sbin/virtinterfaced" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtlxcd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtnetworkd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtnodedevd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtnwfilterd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtproxyd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtqemud" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtsecretd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtstoraged" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtvboxd" "virtd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtxend" "virtd_exec_t"
    rlPhaseEnd

    rlPhaseStartTest "real scenario -- standalone service"
        rlRun "echo ${ROOT_PASSWORD} | passwd --stdin root"
        # start all the services
        for TUPLE in ${ALL_TUPLES} ; do
            SERVICE_NAME=`echo ${TUPLE} | cut -d : -f 1`
            PROCESS_NAME=`echo ${TUPLE} | cut -d : -f 2`
            PROCESS_CONTEXT=`echo ${TUPLE} | cut -d : -f 3`
            if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
                rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "start status" 1
            fi
        done
        rlRun "restorecon -Rv /etc /run /var -e /var/ARTIFACTS" 0-255
        # restart all the services
        for TUPLE in ${ALL_TUPLES} ; do
            SERVICE_NAME=`echo ${TUPLE} | cut -d : -f 1`
            PROCESS_NAME=`echo ${TUPLE} | cut -d : -f 2`
            PROCESS_CONTEXT=`echo ${TUPLE} | cut -d : -f 3`
            if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
                rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "restart status" 1
            fi
        done
        # stop all the services
        for TUPLE in ${ALL_TUPLES} ; do
            SERVICE_NAME=`echo ${TUPLE} | cut -d : -f 1`
            PROCESS_NAME=`echo ${TUPLE} | cut -d : -f 2`
            PROCESS_CONTEXT=`echo ${TUPLE} | cut -d : -f 3`
            if [ -f /usr/lib/systemd/system/${SERVICE_NAME}.service ] ; then
                rlSEService ${ROOT_PASSWORD} ${SERVICE_NAME} ${PROCESS_NAME} ${PROCESS_CONTEXT} "stop status" 1
            fi
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAMES}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

