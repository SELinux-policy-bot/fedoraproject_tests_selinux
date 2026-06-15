#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="coreutils-single"
BOOLEAN="corecmd_bin_sys_resource"
INSTALLED_VARIANT=""

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'" 0,1
        if rpm -q coreutils-single > /dev/null 2>&1; then                                                                                             
            INSTALLED_VARIANT="single"                                                             
        else                                                                                                                                                                           
            INSTALLED_VARIANT="regular"
            rlRun "yum -y install ${PACKAGE} --allowerasing"                                                                        
        fi
        rlAssertRpm ${PACKAGE}
        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
    rlPhaseEnd

    rlPhaseStartTest "RHEL-141858"
        # Boolean and rule exists
        rlRun "getsebool -a | grep ${BOOLEAN}"
        rlSESearchRule "allow NetworkManager_dispatcher_chronyc_t self:capability {sys_resource} [ ${BOOLEAN} ]"
        INTERFACE_NAME="$(ip link show |  head -n 1 | awk -F': ' '/^[0-9]+:/ {print $2}')"

        # No AVC when the boolean is turned on
        rlSEBooleanOn ${BOOLEAN}
        rlRun "nmcli connection up ${INTERFACE_NAME}"
        sleep 5
    rlPhaseEnd

    rlPhaseStartCleanup
        rlSECheckAVC
        rlSEBooleanRestore ${BOOLEAN}
        if [ "$INSTALLED_VARIANT" = "regular" ]; then
            rlRun "yum -y install coreutils --allowerasing"
        fi
    rlPhaseEnd
rlJournalEnd