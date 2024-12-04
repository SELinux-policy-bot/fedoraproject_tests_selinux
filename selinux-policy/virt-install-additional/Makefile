# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/virt-install-additional
#   Description: SELinux interferes with virt-install and related programs
#   Author: Milos Malik <mmalik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/selinux-policy/Regression/virt-install-additional
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
	@echo "Description:     SELinux interferes with virt-install and related programs" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        20m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy selinux-policy-targeted /usr/sbin/service setools-console virt-install libvirt-client numad nbdkit" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Releases:        -RHEL4 -RHEL5 -RHEL6 -RHEL7" >> $(METADATA)
	@echo "Architectures:   aarch64 s390x x86_64" >> $(METADATA)
	@echo "Bug:             RHEL-56029" >> $(METADATA) # RHEL-9
	@echo "Bug:             RHEL-65038" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-65373" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-65383" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-65789" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-69118" >> $(METADATA) # RHEL-10
	@echo "Bug:             RHEL-69920" >> $(METADATA) # RHEL-10

	rhts-lint $(METADATA)

