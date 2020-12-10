# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/kerberos-and-similar
#   Description: SELinux interferes with kerberos programs
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

export TEST=/CoreOS/selinux-policy/Regression/kerberos-and-similar
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE krb5.conf

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
	@echo "Description:     SELinux interferes with kerberos programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        30m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          krb5" >> $(METADATA)
	@echo "Requires:        audit selinux-policy selinux-policy-targeted setools-console libselinux libselinux-utils policycoreutils krb5-server krb5-libs" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5" >> $(METADATA)
	@echo "Bug:             698923" >> $(METADATA) # RHEL-6
	@echo "Bug:             713218" >> $(METADATA) # RHEL-6
	@echo "Bug:             860666" >> $(METADATA) # RHEL-6
	@echo "Bug:             910837" >> $(METADATA) # RHEL-7
	@echo "Bug:             1041629" >> $(METADATA) # RHEL-7
	@echo "Bug:             1065460" >> $(METADATA) # RHEL-7
	@echo "Bug:             1153561" >> $(METADATA) # RHEL-7
	@echo "Bug:             1210421" >> $(METADATA) # RHEL-6
	@echo "Bug:             1220691" >> $(METADATA) # RHEL-6
	@echo "Bug:             1220763" >> $(METADATA) # RHEL-7
	@echo "Bug:             1319933" >> $(METADATA) # RHEL-7
	@echo "Bug:             1337895" >> $(METADATA) # RHEL-6
	@echo "Bug:             1368492" >> $(METADATA) # RHEL-7
	@echo "Bug:             1452215" >> $(METADATA) # RHEL-7
	@echo "Bug:             1600705" >> $(METADATA) # RHEL-7
	@echo "Bug:             1601004" >> $(METADATA) # RHEL-7
	@echo "Bug:             1619252" >> $(METADATA) # RHEL-7
	@echo "Bug:             1664983" >> $(METADATA) # RHEL-8
	@echo "Bug:             1669975" >> $(METADATA) # RHEL-8

	rhts-lint $(METADATA)

