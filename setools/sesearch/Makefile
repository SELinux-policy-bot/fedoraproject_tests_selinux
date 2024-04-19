# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/setools/Sanity/sesearch
#   Description: Does sesearch work well? Does it support all features?
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

export TEST=/CoreOS/setools/Sanity/sesearch
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
	@echo "Description:     Does sesearch work well? Does it support all features?" >> $(METADATA)
	@echo "Type:            Sanity" >> $(METADATA)
	@echo "TestTime:        15m" >> $(METADATA)
	@echo "RunFor:          setools" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "Requires:        python3-setools" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             526460" >> $(METADATA) # Fedora 11
	@echo "Bug:             583915" >> $(METADATA) # RHEL-6
	@echo "Bug:             602166" >> $(METADATA) # RHEL-6
	@echo "Bug:             649711" >> $(METADATA) # RHEL-5
	@echo "Bug:             650094" >> $(METADATA) # RHEL-6
	@echo "Bug:             836213" >> $(METADATA) # RHEL-7
	@echo "Bug:             924588" >> $(METADATA) # RHEL-7
	@echo "Bug:             1029837" >> $(METADATA) # RHEL-7
	@echo "Bug:             1595582" >> $(METADATA) # RHEL-8

	rhts-lint $(METADATA)

