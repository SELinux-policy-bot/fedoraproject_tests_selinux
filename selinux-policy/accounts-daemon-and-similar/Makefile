# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/accounts-daemon-and-similar
#   Description: SELinux interferes with accounts daemon and related programs
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

export TEST=/CoreOS/selinux-policy/Regression/accounts-daemon-and-similar
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
	@echo "Description:     SELinux interferes with accounts daemon and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        10m" >> $(METADATA)
	@echo "RunFor:          accountsservice" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy selinux-policy-targeted setools-console accountsservice glib2 procps-ng realmd initscripts gdm" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHELServer5 -RHELClient5 -RHEL6" >> $(METADATA)
	@echo "Bug:             1456760" >> $(METADATA) # RHEL-7
	@echo "Bug:             1507089" >> $(METADATA) # RHEL-7
	@echo "Bug:             1518211" >> $(METADATA) # RHEL-7
	@echo "Bug:             1595667" >> $(METADATA) # RHEL-7
	@echo "Bug:             1792895" >> $(METADATA) # RHEL-8
	@echo "Bug:             1806126" >> $(METADATA) # Fedora 32
	@echo "Bug:             1811407" >> $(METADATA) # Fedora 32
	@echo "Bug:             1815312" >> $(METADATA) # Fedora 32
	@echo "Bug:             1818696" >> $(METADATA) # Fedora 32
	@echo "Bug:             1819040" >> $(METADATA) # Fedora 32
	@echo "Bug:             1820978" >> $(METADATA) # Fedora 32
	@echo "Bug:             1820992" >> $(METADATA) # Fedora 32
	@echo "Bug:             1821156" >> $(METADATA) # RHEL-8
	@echo "Bug:             1828809" >> $(METADATA) # RHEL-8
	@echo "Bug:             1829013" >> $(METADATA) # Fedora 32
	@echo "Bug:             1829075" >> $(METADATA) # Fedora 32
	@echo "Bug:             1829128" >> $(METADATA) # Fedora 32
	@echo "Bug:             1928546" >> $(METADATA) # Fedora 34
	@echo "Bug:             1928565" >> $(METADATA) # Fedora 34
	@echo "Bug:             1928567" >> $(METADATA) # Fedora 34
	@echo "Bug:             1933687" >> $(METADATA) # Fedora 34
	@echo "Bug:             1933842" >> $(METADATA) # RHEL-9
	@echo "Bug:             1934573" >> $(METADATA) # Fedora 34
	@echo "Bug:             1935232" >> $(METADATA) # RHEL-9

	rhts-lint $(METADATA)

