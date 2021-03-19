# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/ladvd
#   Description: Test coverage for avc denials related to ladvd service.
#   Author: Amith Kumar <apeetham@redhat.com>
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

export TEST=/CoreOS/selinux-policy/Regression/ladvd
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	test -x runtest.sh || chmod a+x runtest.sh
	test -x runtest.sh || chcon -t bin_t runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Amith Kumar <apeetham@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Tests for ladvd service" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        1h" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          ladvd" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        initscripts" >> $(METADATA)
	@echo "Requires:        kernel-headers" >> $(METADATA)
	@echo "Requires:        ladvd" >> $(METADATA)
	@echo "Requires:        ladvd-selinux" >> $(METADATA)
	@echo "Requires:        libpcap" >> $(METADATA)
	@echo "Requires:        libselinux" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
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
	@echo "Releases:        -RHEL4 -RHEL5" >> $(METADATA)
	@echo "Bug:             1834325" >> $(METADATA) # Fedora 32
	@echo "Bug:             1855163" >> $(METADATA) # Fedora 32

	rhts-lint $(METADATA)

