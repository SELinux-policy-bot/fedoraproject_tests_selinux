# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/bz538089-plymouth-operations-denied-during-boot
#   Description: some plymouth operations are denied during boot because of SELinux
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2009 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/bz538089-plymouth-operations-denied-during-boot
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE

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
	@echo "Description:     some plymouth operations are denied during boot because of SELinux" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        30m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        /usr/sbin/service" >> $(METADATA)
	@echo "Requires:        libselinux" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
	@echo "Requires:        plymouth" >> $(METADATA)
	@echo "Requires:        policycoreutils" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHELServer5 -RHELClient5" >> $(METADATA)
	@echo "Bug:             538089" >> $(METADATA) # RHEL-6
	@echo "Bug:             560611" >> $(METADATA) # RHEL-6
	@echo "Bug:             904016" >> $(METADATA) # RHEL-7
	@echo "Bug:             1045382" >> $(METADATA) # RHEL-7
	@echo "Bug:             1131195" >> $(METADATA) # RHEL-6
	@echo "Bug:             1160196" >> $(METADATA) # RHEL-7
	@echo "Bug:             1202429" >> $(METADATA) # Fedora 21
	@echo "Bug:             1517405" >> $(METADATA) # Fedora 27
	@echo "Bug:             1664143" >> $(METADATA) # Fedora 29
	@echo "Bug:             1869814" >> $(METADATA) # RHEL-8
	@echo "Bug:             1871307" >> $(METADATA) # RHEL-8
	@echo "Bug:             2184803" >> $(METADATA) # RHEL-9
	@echo "Bug:             2256442" >> $(METADATA) # Fedora 40

	rhts-lint $(METADATA)

