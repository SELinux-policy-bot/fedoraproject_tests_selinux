# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/firewalld-and-similar
#   Description: SELinux interferes with firewalld and related programs
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

export TEST=/CoreOS/selinux-policy/Regression/firewalld-and-similar
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
	@echo "Description:     SELinux interferes with firewalld and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        30m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          firewalld" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy selinux-policy-targeted setools-console firewalld glib2 nftables procps-ng /usr/sbin/service" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5 -RHEL6" >> $(METADATA)
	@echo "Bug:             907902" >> $(METADATA) # RHEL-7
	@echo "Bug:             989922" >> $(METADATA) # RHEL-7
	@echo "Bug:             1067494" >> $(METADATA) # RHEL-7
	@echo "Bug:             1214853" >> $(METADATA) # RHEL-7
	@echo "Bug:             1221326" >> $(METADATA) # RHEL-7
	@echo "Bug:             1243403" >> $(METADATA) # RHEL-7
	@echo "Bug:             1284902" >> $(METADATA) # RHEL-7
	@echo "Bug:             1304721" >> $(METADATA) # RHEL-7
	@echo "Bug:             1304723" >> $(METADATA) # RHEL-7
	@echo "Bug:             1342235" >> $(METADATA) # RHEL-7
	@echo "Bug:             1342587" >> $(METADATA) # RHEL-7
	@echo "Bug:             1346316" >> $(METADATA) # RHEL-7
	@echo "Bug:             1375576" >> $(METADATA) # RHEL-7
	@echo "Bug:             1418391" >> $(METADATA) # RHEL-7
	@echo "Bug:             1438708" >> $(METADATA) # RHEL-7
	@echo "Bug:             1573501" >> $(METADATA) # RHEL-8
	@echo "Bug:             1593687" >> $(METADATA) # RHEL-8
	@echo "Bug:             1600903" >> $(METADATA) # RHEL-8
	@echo "Bug:             1759010" >> $(METADATA) # RHEL-8
	@echo "Bug:             1989641" >> $(METADATA) # RHEL-9

	rhts-lint $(METADATA)

