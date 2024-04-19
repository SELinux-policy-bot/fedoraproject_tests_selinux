# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/setools/Sanity/seinfo
#   Description: Does seinfo work well? Does it support all features?
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

export TEST=/CoreOS/setools/Sanity/seinfo
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
	@echo "Description:     Does seinfo work well? Does it support all features?" >> $(METADATA)
	@echo "Type:            Sanity" >> $(METADATA)
	@echo "TestTime:        20m" >> $(METADATA)
	@echo "RunFor:          setools" >> $(METADATA)
	@echo "Requires:        setools" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Requires:        grep" >> $(METADATA)
	@echo "Requires:        diffutils" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             499247" >> $(METADATA) # Fedora
	@echo "Bug:             584286" >> $(METADATA) # RHEL-5
	@echo "Bug:             649699" >> $(METADATA) # RHEL-5
	@echo "Bug:             650092" >> $(METADATA) # RHEL-6
	@echo "Bug:             739628" >> $(METADATA) # RHEL-6
	@echo "Bug:             928705" >> $(METADATA) # RHEL-7
	@echo "Bug:             1581761" >> $(METADATA) # RHEL-8

	rhts-lint $(METADATA)

