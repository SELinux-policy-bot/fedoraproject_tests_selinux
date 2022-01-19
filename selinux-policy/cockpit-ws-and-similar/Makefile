# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/cockpit-ws-and-similar
#   Description: SELinux interferes with cockpit-ws and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/cockpit-ws-and-similar
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE testpolicy.te

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
	@echo "Description:     SELinux interferes with cockpit-ws and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        10m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy selinux-policy-targeted setools-console glib2 cockpit-ws net-tools nmap-ncat cockpit-dashboard cockpit-bridge psmisc selinux-policy-devel" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Architectures:   x86_64" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5 -RHEL6" >> $(METADATA)
	@echo "Bug:             1100808" >> $(METADATA) # RHEL-7
	@echo "Bug:             1214223" >> $(METADATA) # RHEL-7
	@echo "Bug:             1279429" >> $(METADATA) # RHEL-7
	@echo "Bug:             1283955" >> $(METADATA) # RHEL-7
	@echo "Bug:             1374572" >> $(METADATA) # RHEL-7
	@echo "Bug:             1381914" >> $(METADATA) # RHEL-7
	@echo "Bug:             1402316" >> $(METADATA) # RHEL-7
	@echo "Bug:             1402495" >> $(METADATA) # RHEL-7
	@echo "Bug:             1413509" >> $(METADATA) # RHEL-7
	@echo "Bug:             1561053" >> $(METADATA) # Fedora 28
	@echo "Bug:             1584167" >> $(METADATA) # Fedora 28
	@echo "Bug:             1609929" >> $(METADATA) # Fedora 28
	@echo "Bug:             1613638" >> $(METADATA) # Fedora 28
	@echo "Bug:             1615318" >> $(METADATA) # RHEL-8
	@echo "Bug:             1629678" >> $(METADATA) # RHEL-8
	@echo "Bug:             1718814" >> $(METADATA) # RHEL-8
	@echo "Bug:             1979182" >> $(METADATA) # RHEL-8

	rhts-lint $(METADATA)

