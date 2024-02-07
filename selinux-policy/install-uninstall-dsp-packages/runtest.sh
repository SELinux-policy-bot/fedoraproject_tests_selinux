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
ADDITIONAL_DSP_PACKAGES="additional-dsp-packages.txt"
TMPDIR=${TMPDIR-"/var/tmp"}
OUTDIR="${TMPDIR}/test-output"
FCONTEXT_LIST="${OUTDIR}/semanage-fcontext"
FCONTEXT_LIST2="${OUTDIR}/semanage-fcontext2"
FCONTEXT_LIST_VARRUN="${OUTDIR}/semanage-fcontext-varrun"
RESTORECON_RVN_RUN="${OUTDIR}/restorecon-rvn-run"
RPMQA="${OUTDIR}/rpmqa"
SEMODULE_LIST="${OUTDIR}/semodule-list"
SEMODULE_LIST_DSP="${OUTDIR}/semodule-list-dsp"
PERMISSIVE_DOMAINS="${OUTDIR}/permissive-domains"
UNCONFINED_DOMAINS="${OUTDIR}/unconfined-domains"
DBUS_SENDMSG="${OUTDIR}/dbus-sendmsg"
mkdir -p ${OUTDIR}

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

    rlPhaseStartTest "Install test for dsp packages"
        rlRun "dnf list \"*-selinux*\" --enablerepo=\"*\" --disablerepo=\"beaker-tasks\" --disablerepo=\"*-source\" --disablerepo=\"*-debuginfo\" > install-list"
	# limit the list to not installed packages
        rlRun "sed -i '1,/Available Packages/d' install-list"
	# exclude packages from the beaker-tasks repo
        rlRun "sed -i '/beaker-tasks/d' install-list"
	# exclude debuginfo packages
        rlRun "sed -i '/-debuginfo/d' install-list"
	# packages names only
        rlRun "awk '{print \$1}' install-list > pkgonlylist"
	# exclude updates-source
        rlRun "grep -vE '(.src)' pkgonlylist | sort -u > install-pkgs"
	# include additional packages which do not match the "*-selinux" pattern
	# currently for Fedora only
	if rlIsFedora ">=38"
	then
	  # remove comments and blank lines
	  rlRun "sed '/^[#]/d;/^$/d' ${ADDITIONAL_DSP_PACKAGES} >> install-pkgs"
	fi
	# use the same list for checks of the subsequent uninstallation
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
    rlPhaseEnd

    ### Checks performed with all dsp packages installed

    ### Status of /run and /var/run equivalency
    rlPhaseStartTest "Check /run equivalency status"
	rlRun "semanage fcontext -l > ${FCONTEXT_LIST}"
	if grep -q "/run = /var/run" ${FCONTEXT_LIST}; then
	    rlLogInfo "Legacy equivalency settings \"/run = /var/run\" are in place."
	elif grep -q "/var/run = /run" ${FCONTEXT_LIST}; then
	    rlLog "New equivalency settings /\"var/run = /run\" are in place."
	    grep -v "/var/run = /run" ${FCONTEXT_LIST} > ${FCONTEXT_LIST2}
	    if grep -q "^/var/run" ${FCONTEXT_LIST2}; then
		rlLogWarning "/var/run entries found in the file context database"
		rlRun "sed '/^\/var\/run/!d; s|[ \t].*$||' ${FCONTEXT_LIST2} | uniq > ${FCONTEXT_LIST_VARRUN}"

		# List /var/run rules which do not have an equivalent one in /run
		while read line
		do
		    if ! grep -q "^${line#/var}" ${FCONTEXT_LIST2}; then
		        rlLog "Dup rule does not exist in /run: \"$line\""
		    fi
		done < ${FCONTEXT_LIST_VARRUN}
	    fi
	else rlLogWarning "None or unknown /run equivalency settings."
	fi

	[ "$DEBUG" = "yes" ] ||
	rlRun "rm -f ${FCONTEXT_LIST} ${FCONTEXT_LIST_VARRUN}"
    rlPhaseEnd

    ### Store some data which might be of some use later
    rlPhaseStartTest "Gather relevant data"
	if [ "${DEBUG}" = "yes" ]; then
	    rlRun "restorecon -Rvn /run > ${RESTORECON_RVN_RUN}"
	    rlRun "rpm -qa | sort > ${RPMQA}"
	    rlRun "semanage permissive -l > ${PERMISSIVE_DOMAINS}"
	    rlRun "seinfo -xa unconfined_domain_type > ${UNCONFINED_DOMAINS}"
	    rlRun "semodule -lfull > ${SEMODULE_LIST}"
	    rlRun "grep -v ^100 ${SEMODULE_LIST} > ${SEMODULE_LIST_DSP}"
	    rlRpmInstall "perl"
	    rlRun "./dbus-sendmsg.pl > ${DBUS_SENDMSG}"
	fi
    rlPhaseEnd

    rlPhaseStartTest "Uninstall test for dsp packages"
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
	[ "$DEBUG" = "yes" ] ||
        rlRun "rm -f install-list pkgonlylist install-pkgs uninstall-pkgs pkglist.report"
        rlSECheckAVC --ignore 'type=USER_AVC.*denied.* send_msg .*scontext=.*:unconfined_t:.*tcontext=.*:system_dbusd_t:.*tclass=dbus' \
                     --ignore 'type=USER_AVC.* start .*:unconfined_t:.*:init_t:.*tclass=system' \
                     --ignore 'type=USER_AVC.* start .*:unconfined_t:.*:init_var_run_t:.*tclass=service'
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
