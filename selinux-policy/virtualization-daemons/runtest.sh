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
if rlIsFedora ">39"; then
ALL_TUPLES="libvirtd:libvirtd:virtd_t \
            virtinterfaced:virtinterfaced:virtinterfaced_t \
            virtlockd:virtlockd:virtlogd_t \
            virtlogd:virtlogd:virtlogd_t \
            virtlxcd:virtlxcd:virtd_lxc_t \
            virtnetworkd:virtnetworkd:virtnetworkd_t \
            virtnodedevd:virtnodedevd:virtnodedevd_t \
            virtnwfilterd:virtnwfilterd:virtnwfilterd_t \
            virtproxyd:virtproxyd:virtproxyd_t \
            virtqemud:virtqemud:virtqemud_t \
            virtsecretd:virtsecretd:virtsecretd_t \
            virtstoraged:virtstoraged:virtstoraged_t \
            virtvboxd:virtvboxd:virtvboxd_t"
#            virtxend:virtxend:virtxend_t"
else
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
fi

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "rpm -qa libvirt\*"

        rlServiceStop ${SERVICE_NAMES}
        rlFileBackup /etc/shadow

        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "SELinux contexts and rules"
      if rlIsFedora ">39"; then
        rlSEMatchPathCon "/usr/sbin/virtinterfaced" "virtinterfaced_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtlxcd" "virtd_lxc_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtnetworkd" "virtnetworkd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtnodedevd" "virtnodedevd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtnwfilterd" "virtnwfilterd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtproxyd" "virtproxyd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtqemud" "virtqemud_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtsecretd" "virtsecretd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtstoraged" "virtstoraged_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtvboxd" "virtvboxd_exec_t"
        rlSEMatchPathCon "/usr/sbin/virtxend" "virtxend_exec_t"
      else
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
      fi
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
                rlRun "virt-admin -c ${SERVICE_NAME}:///system exit" 0,1
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

    if seinfo -a | grep -q virt_driver_domain ; then
    rlPhaseStartTest "bz#2291273"
        rlSESearchRule "allow virtnetworkd_t unconfined_t : dir { search } [ ]"
        rlSESearchRule "allow virtnetworkd_t unconfined_t : file { open read } [ ]"
        rlSESearchRule "allow virtnodedevd_t unconfined_t : dir { search } [ ]"
        rlSESearchRule "allow virtnodedevd_t unconfined_t : file { open read } [ ]"
        rlSESearchRule "allow virtnwfilterd_t unconfined_t : dir { search } [ ]"
        rlSESearchRule "allow virtnwfilterd_t unconfined_t : file { open read } [ ]"
        rlSESearchRule "allow virtsecretd_t unconfined_t : dir { search } [ ]"
        rlSESearchRule "allow virtsecretd_t unconfined_t : file { open read } [ ]"
        rlSESearchRule "allow virtstoraged_t unconfined_t : dir { search } [ ]"
        rlSESearchRule "allow virtstoraged_t unconfined_t : file { open read } [ ]"
        rlSESearchRule "allow virtvboxd_t unconfined_t : dir { search } [ ]"
        rlSESearchRule "allow virtvboxd_t unconfined_t : file { open read } [ ]"
    rlPhaseEnd
    fi

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC

        rlFileRestore
        rlServiceRestore ${SERVICE_NAMES}
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

