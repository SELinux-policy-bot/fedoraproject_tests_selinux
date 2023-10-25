#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Sanity/install-uninstall-dsp-packages
#   Description: Test and discover conflicts if any, during installation of 
#   third-party or DSP packages.
#   Author: Amith Kumar <apeetham@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc.
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
SKIP_REMOVAL=${SKIP_REMOVAL:-""}
SKIP_INSTALL=${SKIP_INSTALL:-""}
INSTALL_ONLY=${INSTALL_ONLY:-""}

# Function to create a report template for install test
function install_report() {
echo "" > pkglist.report
echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> pkglist.report
echo '@       LIST OF PACKAGES TO BE INSTALLED       @' >> pkglist.report
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> pkglist.report
cat install-pkgs >> pkglist.report
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> pkglist.report
echo "" >> pkglist.report
echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> pkglist.report
echo '@       INSTALLATION : Test Report             @' >> pkglist.report
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> pkglist.report
}

# Function to create a report template for uninstall test
function uninstall_report() {
echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> pkglist.report
echo '@       UNINSTALLATION : Test Report           @' >> pkglist.report
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> pkglist.report
}

# Function to summarize the test report
function summary_report() {
echo '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@' >> pkglist.report
echo '@           TEST SUMMARY                       @' >> pkglist.report
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> pkglist.report
SEL=`cat install-pkgs | wc -l`
PASS1=`grep "installation : PASS" pkglist.report | wc -l`
FAIL1=`grep "installation : FAIL" pkglist.report | wc -l`
PASS2=`grep "removal : PASS" pkglist.report | wc -l`
FAIL2=`grep "removal : FAIL" pkglist.report | wc -l`
echo "Total no. of packages selected for installation : $SEL" >> pkglist.report
echo "Total no. of successful package installation : $PASS1" >> pkglist.report
echo "Total no. of failed package installation : $FAIL1" >> pkglist.report
echo "Total no. of successful package removal : $PASS2" >> pkglist.report
echo "Total no. of failed package removal : $FAIL2" >> pkglist.report
echo "" >> pkglist.report
if [ -f "Err_file" ]; then
    echo "DETAILED ERROR LOG (IF ANY)" >> pkglist.report
    echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> pkglist.report
    cat Err_file >> pkglist.report
fi
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESetEnforce
        rlSEStatus
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "Install and Uninstall test for dsp packages"
        rlRun "dnf list *selinux* --enablerepo=\"*\" > install-list"
        rlRun "sed -i '1,/Available Packages/d' install-list"
        rlRun "sed -i '/beaker-tasks/d' install-list"
        rlRun "awk '{print \$1}' install-list > pkgonlylist"
        rlRun "grep -vE '(.src)' pkgonlylist | sort -u > install-pkgs"
        rlRun "cp -f install-pkgs uninstall-pkgs"
        rlRun "install_report"
        # Following loop will read each package from file install-pkgs
        # and will attempt to install it using dnf utility. Both
        # successful and failed attempts will be reported and the
        # report will be published in the end.
        cat install-pkgs | while read line
        do
            if dnf -q -y install --enablerepo="*" $line
            then
                rlLog "$line installation : PASS"
                echo "$line installation : PASS" >> pkglist.report
            else
                rlLog "$line installation : FAIL"
                echo "$line installation : FAIL" >> pkglist.report
                sed -i "/$line/d" uninstall-pkgs
                echo "Installation Failed for : $line" >> Err_file
                dnf -q -y install --enablerepo="*" $line 2>> Err_file
                echo "" >> Err_file
            fi
        done
        echo "" >> pkglist.report
        rlRun "uninstall_report"
        # Following loop will read each package from file install-pkgs
        # and will attempt to un-install it using dnf utility.
        cat uninstall-pkgs | while read line
        do
            if dnf -q -y remove $line
            then
                rlLog "$line removal : PASS"
                echo "$line removal : PASS" >> pkglist.report
            else
                rlLog "$line removal : FAIL"
                echo "$line removal : FAIL" >> pkglist.report
                echo "Removal Failed for : $line" >> Err_file
                dnf -q -y remove $line 2>> Err_file
                echo "" >> Err_file
            fi
        done
        echo "" >> pkglist.report
        rlRun "summary_report"
        rlAssertNotGrep "FAIL" pkglist.report
        rlRun "cat pkglist.report"
    rlPhaseEnd

    rlPhaseStartCleanup
        if [ -f "Err_file" ]; then
            rlRun "rm -f Err_file"
        fi
        rlRun "rm -f install-list pkgonlylist install-pkgs uninstall-pkgs pkglist.report"
        rlSECheckAVC --ignore 'type=USER_AVC.*denied.* send_msg .*scontext=.*:unconfined_t:.*tcontext=.*:system_dbusd_t:.*tclass=dbus' \
                     --ignore 'type=USER_AVC.* start .*:unconfined_t:.*:init_t:.*tclass=system' \
                     --ignore 'type=USER_AVC.* start .*:unconfined_t:.*:init_var_run_t:.*tclass=service'
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
