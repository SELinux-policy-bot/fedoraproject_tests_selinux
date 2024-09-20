# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/hostapd-and-similar
#   Description: SELinux interferes with hostapd and related programs
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

export TEST=/CoreOS/selinux-policy/Regression/hostapd-and-similar
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
	@echo "Description:     SELinux interferes with hostapd and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        10m" >> $(METADATA)
	@echo "RunFor:          hostapd" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy selinux-policy-targeted setools-console hostapd /usr/sbin/service kernel-modules-internal" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5 -RHEL6" >> $(METADATA)
	@echo "Bug:             1224405" >> $(METADATA) # Fedora 22
	@echo "Bug:             1225245" >> $(METADATA) # Fedora 22
	@echo "Bug:             1237343" >> $(METADATA) # Fedora 22
	@echo "Bug:             1266068" >> $(METADATA) # Fedora 23
	@echo "Bug:             1273570" >> $(METADATA) # Fedora 23
	@echo "Bug:             1278569" >> $(METADATA) # Fedora 23
	@echo "Bug:             1282179" >> $(METADATA) # Fedora 23
	@echo "Bug:             1334021" >> $(METADATA) # Fedora 24
	@echo "Bug:             1343683" >> $(METADATA) # Fedora 24
	@echo "Bug:             1977676" >> $(METADATA) # RHEL-8
	@echo "Bug:             1979968" >> $(METADATA) # RHEL-9
	@echo "Bug:             1784253" >> $(METADATA) # Fedora 35
	@echo "Bug:             2032277" >> $(METADATA) # Fedora 35
	@echo "Bug:             RHEL-59683" >> $(METADATA) # RHEL-9

	rhts-lint $(METADATA)

