# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Sanity/systemd-generators
#   Description: Testing systemd system generators which are SELinux confined
#   Author: Zdenek Pytela <zpytela@redhat.com>
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

export TEST=/CoreOS/selinux-policy/Sanity/systemd-generators
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE 71-default.network 71-default-off.network mnt-loop.mount tty.conf

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
	@echo "Owner:           Zdenek Pytela <zpytela@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Testing SELinux confined systemd system generators" >> $(METADATA)
	@echo "Type:            Sanity" >> $(METADATA)
	@echo "TestTime:        15m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
	@echo "Requires:        policycoreutils" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Requires:        zram-generator" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Environment:     SYSTEMD_PAGER=\"\"" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Releases:        -RHEL5" >> $(METADATA)
	@echo "Releases:        -RHEL6" >> $(METADATA)
	@echo "Releases:        -RHEL7" >> $(METADATA)
	@echo "Bug:             2230226" >> $(METADATA) # Fedora 39
	@echo "Bug:             RHEL-72549" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-75879" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-98656" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-100415" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-100721" >> $(METADATA) # RHEL-10

	rhts-lint $(METADATA)

