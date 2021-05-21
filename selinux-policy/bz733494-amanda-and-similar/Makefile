# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/bz733494-amanda-and-similar
#   Description: SELinux interferes with amanda and related tools
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/bz733494-amanda-and-similar
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE krb5.conf krb5.keytab

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x runtest.sh
	chcon -t bin_t runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Milos Malik <mmalik@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     SELinux interferes with amanda and related tools" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        15m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          amanda" >> $(METADATA)
	@echo "Requires:        amanda" >> $(METADATA)
	@echo "Requires:        amanda-client" >> $(METADATA)
	@echo "Requires:        amanda-server" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        initscripts" >> $(METADATA)
	@echo "Requires:        libselinux" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
	@echo "Requires:        nc" >> $(METADATA)
	@echo "Requires:        net-tools" >> $(METADATA)
	@echo "Requires:        nmap-ncat" >> $(METADATA)
	@echo "Requires:        policycoreutils" >> $(METADATA)
	@echo "Requires:        procps-ng" >> $(METADATA)
	@echo "Requires:        krb5-workstation" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Requires:        setools" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "Requires:        xinetd" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             283971" >> $(METADATA) # RHEL-5
	@echo "Bug:             498596" >> $(METADATA) # RHEL-5
	@echo "Bug:             729361" >> $(METADATA) # RHEL-6
	@echo "Bug:             733494" >> $(METADATA) # RHEL-6
	@echo "Bug:             965140" >> $(METADATA) # RHEL-7
	@echo "Bug:             1371561" >> $(METADATA) # RHEL-7
	@echo "Bug:             1452444" >> $(METADATA) # RHEL-7
	@echo "Bug:             1623052" >> $(METADATA) # RHEL-7
	@echo "Bug:             1630963" >> $(METADATA) # RHEL-7
	@echo "Bug:             1739137" >> $(METADATA) # RHEL-8
	@echo "Bug:             1960513" >> $(METADATA) # Fedora 34

	rhts-lint $(METADATA)

