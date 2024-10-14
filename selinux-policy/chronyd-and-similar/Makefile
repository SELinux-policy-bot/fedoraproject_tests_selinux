# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/chronyd-and-similar
#   Description: SELinux interferes with chronyd and related programs
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

export TEST=/CoreOS/selinux-policy/Regression/chronyd-and-similar
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE chrony-nts-test.sh

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x runtest.sh chrony-nts-test.sh
	chcon -t bin_t runtest.sh chrony-nts-test.sh

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Milos Malik <mmalik@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     SELinux interferes with chronyd and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        1h" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          chrony" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy-mls selinux-policy-targeted setools-console chrony ksh nscd /usr/bin/certtool /usr/sbin/service socat linuxptp" >> $(METADATA) # EPEL
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Architectures:   i386 ppc64 x86_64" >> $(METADATA)
	@echo "Bug:             974992" >> $(METADATA) # RHEL-7
	@echo "Bug:             978993" >> $(METADATA) # RHEL-6
	@echo "Bug:             1243764" >> $(METADATA) # RHEL-7
	@echo "Bug:             1243987" >> $(METADATA) # RHEL-7
	@echo "Bug:             1273116" >> $(METADATA) # RHEL-7
	@echo "Bug:             1281473" >> $(METADATA) # RHEL-6
	@echo "Bug:             1290310" >> $(METADATA) # RHEL-6
	@echo "Bug:             1350765" >> $(METADATA) # RHEL-7
	@echo "Bug:             1390657" >> $(METADATA) # RHEL-6
	@echo "Bug:             1416015" >> $(METADATA) # RHEL-7
	@echo "Bug:             1421248" >> $(METADATA) # RHEL-7
	@echo "Bug:             1425408" >> $(METADATA) # RHEL-7
	@echo "Bug:             1440791" >> $(METADATA) # RHEL-7
	@echo "Bug:             1470150" >> $(METADATA) # RHEL-7
	@echo "Bug:             1508486" >> $(METADATA) # RHEL-7
	@echo "Bug:             1509379" >> $(METADATA) # RHEL-7
	@echo "Bug:             1509927" >> $(METADATA) # RHEL-7
	@echo "Bug:             1530525" >> $(METADATA) # RHEL-7
	@echo "Bug:             1567753" >> $(METADATA) # RHEL-7
	@echo "Bug:             1568281" >> $(METADATA) # RHEL-7
	@echo "Bug:             1574418" >> $(METADATA) # RHEL-7
	@echo "Bug:             1575002" >> $(METADATA) # RHEL-7
	@echo "Bug:             1577057" >> $(METADATA) # RHEL-7
	@echo "Bug:             1593267" >> $(METADATA) # RHEL-7
	@echo "Bug:             1593607" >> $(METADATA) # RHEL-8
	@echo "Bug:             1596563" >> $(METADATA) # RHEL-7
	@echo "Bug:             1618757" >> $(METADATA) # RHEL-7
	@echo "Bug:             1622499" >> $(METADATA) # RHEL-8
	@echo "Bug:             1652079" >> $(METADATA) # RHEL-7
	@echo "Bug:             1696252" >> $(METADATA) # RHEL-8
	@echo "Bug:             1772852" >> $(METADATA) # RHEL-8
	@echo "Bug:             1895825" >> $(METADATA) # RHEL-9
	@echo "Bug:             1900143" >> $(METADATA) # Fedora 34
	@echo "Bug:             1961207" >> $(METADATA) # RHEL-8
	@echo "Bug:             2008894" >> $(METADATA) # Fedora 35
	@echo "Bug:             2065313" >> $(METADATA) # RHEL-8
	@echo "Bug:             2118628" >> $(METADATA) # RHEL-8
	@echo "Bug:             2118631" >> $(METADATA) # RHEL-9
	@echo "Bug:             2173604" >> $(METADATA) # RHEL-9
	@echo "Bug:             2169949" >> $(METADATA) # Fedora-38
	@echo "Bug:             RHEL-18219" >> $(METADATA) # RHEL-9

	rhts-lint $(METADATA)

