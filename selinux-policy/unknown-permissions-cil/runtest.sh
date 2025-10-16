#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Unknown permissions are now handled as errors in CIL
#   Author: Jan Janasek <jjanasek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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
FILE="my_policy.cil"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlRun "sestatus"
	echo "(type test_domain_t)" > $FILE
	echo "(type test_file_t)" >> $FILE
        sleep 2
    rlPhaseEnd


    rlPhaseStartTest "permission watch"
       echo "(allow test_domain_t test_file_t (dir (watch)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (dir (watching)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd

    rlPhaseStartTest "permission that is not defined in a class"
       echo "(allow test_domain_t test_file_t (dir (add_name)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (file (add_name)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd
    
    rlPhaseStartTest "permission sendto"
        echo "(allow test_domain_t test_file_t (node (sendto)))" >> $FILE 
        rlRun "semodule -i $FILE"
        head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
        echo "(allow test_domain_t test_file_t (node (sendsto)))" >> $FILE 
        rlRun "semodule -i $FILE" 1
        head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
        echo "(allow test_domain_t test_file_t (dir (sendto)))" >> $FILE 
        rlRun "semodule -i $FILE" 1
        head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd

    rlPhaseStartTest "permission stop"
       echo "(allow test_domain_t test_file_t (system (stop)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (system (stops)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (dir (stop)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd
    
    rlPhaseStartTest "permission reload"
       echo "(allow test_domain_t test_file_t (service (reload)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (service (reloads)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (dir (reload)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd
    
    rlPhaseStartTest "permission use"
       echo "(allow test_domain_t test_file_t (fd (use)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (fd (using)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (dir (use)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd
    
    rlPhaseStartTest "permission flow_in"
       echo "(allow test_domain_t test_file_t (packet (flow_in)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (packet (flows_in)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (system (flow_in)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd
    
    rlPhaseStartTest "permission contains"
       echo "(allow test_domain_t test_file_t (context (contains)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (context (contain)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (fd (contains)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd
    
    rlPhaseStartTest "permission lock"
       echo "(allow test_domain_t test_file_t (shm (lock)))" >> $FILE 
       rlRun "semodule -i $FILE"
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (shm (locked)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
       echo "(allow test_domain_t test_file_t (system (lock)))" >> $FILE 
       rlRun "semodule -i $FILE" 1
       head -n -1 $FILE > "temp.txt" && mv "temp.txt" $FILE
    rlPhaseEnd

    rlPhaseStartCleanup
	    rm $FILE
        rlRun "semodule -r my_policy"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
