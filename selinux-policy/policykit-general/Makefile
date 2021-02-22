# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/policykit-general
#   Description: Test for BZ#962791 (SELinux is preventing /usr/lib/polkit-1/polkitd)
#   Author: Michal Trunecka <mtruneck@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/policykit-general
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE ssh.exp

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x runtest.sh ssh.exp
	chcon -t bin_t runtest.sh ssh.exp

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Michal Trunecka <mtruneck@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Test for BZ#962791 (SELinux is preventing /usr/lib/polkit-1/polkitd)" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        20m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          polkit" >> $(METADATA)
	@echo "Requires:        audit selinux-policy polkit glib2 libselinux libselinux-utils policycoreutils setools-console psmisc shadow-utils expect openssh-clients" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5" >> $(METADATA)
	@echo "Bug:             960669" >> $(METADATA) # RHEL-7
	@echo "Bug:             962791" >> $(METADATA) # RHEL-7
	@echo "Bug:             965143" >> $(METADATA) # RHEL-7
	@echo "Bug:             1003799" >> $(METADATA) # RHEL-6
	@echo "Bug:             1301561" >> $(METADATA) # RHEL-6
	@echo "Bug:             1364513" >> $(METADATA) # RHEL-7
	@echo "Bug:             1574389" >> $(METADATA) # RHEL-7
	@echo "Bug:             1583082" >> $(METADATA) # RHEL-7
	@echo "Bug:             1727902" >> $(METADATA) # RHEL-8

	rhts-lint $(METADATA)

