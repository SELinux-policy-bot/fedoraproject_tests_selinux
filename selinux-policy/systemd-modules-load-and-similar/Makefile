# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/systemd-modules-load-and-similar
#   Description: SELinux interferes with the systemd-modules-load service and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/systemd-modules-load-and-similar
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
	@echo "Description:     SELinux interferes with the systemd-modules-load service and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        10m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          systemd" >> $(METADATA)
	@echo "Requires:        audit initscripts libselinux libselinux-utils policycoreutils rdma-core selinux-policy selinux-policy-targeted setools-console openssh-clients systemd-udev" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5 -RHEL6 -RHEL7" >> $(METADATA)
	@echo "Bug:             1358526" >> $(METADATA) # Fedora 24
	@echo "Bug:             1358960" >> $(METADATA) # Fedora 24
	@echo "Bug:             1360157" >> $(METADATA) # Fedora 24
	@echo "Bug:             1360488" >> $(METADATA) # Fedora 24
	@echo "Bug:             1437153" >> $(METADATA) # Fedora 25
	@echo "Bug:             1438253" >> $(METADATA) # Fedora 25
	@echo "Bug:             1490015" >> $(METADATA) # Fedora 27
	@echo "Bug:             1493293" >> $(METADATA) # Fedora 27
	@echo "Bug:             1697632" >> $(METADATA) # Fedora 30
	@echo "Bug:             1698200" >> $(METADATA) # Fedora 30
	@echo "Bug:             1699559" >> $(METADATA) # Fedora 30
	@echo "Bug:             1819161" >> $(METADATA) # Fedora 32
	@echo "Bug:             1823246" >> $(METADATA) # RHEL-8
	@echo "Bug:             1824196" >> $(METADATA) # Fedora 32
	@echo "Bug:             1829700" >> $(METADATA) # Fedora 32
	@echo "Bug:             1833502" >> $(METADATA) # Fedora 32
	@echo "Bug:             1838933" >> $(METADATA) # Fedora 32
	@echo "Bug:             1942267" >> $(METADATA) # Fedora 32
	@echo "Bug:             1972372" >> $(METADATA) # RHEL 9
	@echo "Bug:             2088257" >> $(METADATA) # RHEL-9
	@echo "Bug:             2088258" >> $(METADATA) # RHEL-9

	rhts-lint $(METADATA)

