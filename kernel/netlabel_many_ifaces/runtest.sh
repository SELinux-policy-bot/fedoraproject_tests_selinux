#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# SPDX-License-Identifier: GPLv2
# Copyright (c) 2020 Red Hat, Inc.
# Author: Ondrej Mosnacek <omosnace@redhat.com>

# Include Beakerlib environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

NR_IFACES=10
NR_IPS=8

function iface_name() { echo "mygre$1"; }
function iface_ip() { echo "10.123.$1.$2"; }

function ip_label() { echo "system_u:object_r:var_t:s0:c$1"; }

rlJournalStart
    rlPhaseStartSetup
        rlRun "uname -r"
        rlRun "rpm -q netlabel_tools"

        rlLog "Create $NR_IFACES dummy interfaces, each with $NR_IPS IPs..."
        for (( i = 0; i < $NR_IFACES; i++ )); do
            rlRun "ip link add $(iface_name $i) type gretap local 127.0.0.$i remote 127.0.0.$i"
            for (( j = 0; j < $NR_IPS; j++ )); do
                rlRun "ip addr add $(iface_ip $i $j) dev $(iface_name $i)"
            done
            rlRun "ip link set $(iface_name $i) up"
        done
        rlFileBackup /etc/netlabel.rules
        rlRun "tee /etc/netlabel.rules" 0 "Generate netlabel configuration" <<EOF
cipsov4 add doi:9999 local
map del default
map add default address:0.0.0.0/0 protocol:unlbl
map add default address:127.0.0.1 protocol:cipsov4,9999

$(
for (( i = 0; i < $NR_IFACES; i++ )); do
    for (( j = 0; j < $NR_IPS; j++ )); do
        echo "unlbl add interface:$(iface_name $i) address:$(iface_ip $i $j)/32 label:$(ip_label $j)"
    done
done
)
EOF
        rlServiceStart netlabel
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "netlabel-config reset" 0 "Attempt to reset all rules"
        rlRun "netlabelctl unlbl list -p | wc -l" 0 "Print rules after reset"
        rlAssertEquals "Assert that there are no rules after reset" \
            "$(netlabelctl unlbl list -p | wc -l)" "2"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlServiceRestore
        for (( i = 0; i < $NR_IFACES; i++ )); do
            rlRun "ip link del $(iface_name $i)" 0-1
        done
        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
