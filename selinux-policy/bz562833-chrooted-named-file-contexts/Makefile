# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/bz562833-chrooted-named-file-contexts
#   Description: some named files in chroot-ed environment have wrong SELinux labels
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/bz562833-chrooted-named-file-contexts
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
	@echo "Description:     some named files in chroot-ed environment have wrong SELinux labels" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        2h" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        bind" >> $(METADATA)
	@echo "Requires:        bind-chroot" >> $(METADATA)
	@echo "Requires:        caching-nameserver" >> $(METADATA)
	@echo "Requires:        grep" >> $(METADATA)
	@echo "Requires:        /usr/sbin/service" >> $(METADATA)
	@echo "Requires:        libselinux" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
	@echo "Requires:        policycoreutils" >> $(METADATA)
	@echo "Requires:        procps" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             451970" >> $(METADATA) # RHEL-5
	@echo "Bug:             562833" >> $(METADATA) # RHEL-5
	@echo "Bug:             578187" >> $(METADATA) # RHEL-5
	@echo "Bug:             698257" >> $(METADATA) # RHEL-5
	@echo "Bug:             739886" >> $(METADATA) # RHEL-6
	@echo "Bug:             843732" >> $(METADATA) # RHEL-6
	@echo "Bug:             859231" >> $(METADATA) # RHEL-6
	@echo "Bug:             916173" >> $(METADATA) # RHEL-7
	@echo "Bug:             1012051" >> $(METADATA) # RHEL-7
	@echo "Bug:             1103439" >> $(METADATA) # RHEL-6
	@echo "Bug:             1110397" >> $(METADATA) # RHEL-6
	@echo "Bug:             1166281" >> $(METADATA) # RHEL-7
	@echo "Bug:             1199473" >> $(METADATA) # RHEL-7
	@echo "Bug:             1312972" >> $(METADATA) # RHEL-7
	@echo "Bug:             1683754" >> $(METADATA) # RHEL-7
	@echo "Bug:             1759505" >> $(METADATA) # RHEL-8
	@echo "Bug:             1827591" >> $(METADATA) # Fedora 30
	@echo "Bug:             1923929" >> $(METADATA) # RHEL-9
	@echo "Bug:             2223725" >> $(METADATA) # Fedora 39
	@echo "Bug:             2224352" >> $(METADATA) # Fedora 38
	@echo "Bug:             2226703" >> $(METADATA) # Fedora 38

	rhts-lint $(METADATA)

