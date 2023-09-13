# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/bz533007-unable-to-start-kdump-service
#   Description: kdump service cannot be started because of SELinux
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

export TEST=/CoreOS/selinux-policy/Regression/bz533007-unable-to-start-kdump-service
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE testpolicy.te run.exp id_rsa id_rsa.pub

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	chmod a+x runtest.sh run.exp
	chcon -t bin_t runtest.sh run.exp

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Milos Malik <mmalik@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     kdump service cannot be started because of SELinux" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        15m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "Requires:        audit" >> $(METADATA)
	@echo "Requires:        expect" >> $(METADATA)
	@echo "Requires:        /usr/sbin/service" >> $(METADATA)
	@echo "Requires:        kexec-tools" >> $(METADATA)
	@echo "Requires:        grubby" >> $(METADATA)
	@echo "Requires:        libselinux" >> $(METADATA)
	@echo "Requires:        libselinux-utils" >> $(METADATA)
	@echo "Requires:        policycoreutils" >> $(METADATA)
	@echo "Requires:        sed" >> $(METADATA)
	@echo "Requires:        selinux-policy" >> $(METADATA)
	@echo "Requires:        selinux-policy-mls" >> $(METADATA)
	@echo "Requires:        selinux-policy-targeted" >> $(METADATA)
	@echo "Requires:        setools-console" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             533007" >> $(METADATA) # RHEL-6
	@echo "Bug:             533366" >> $(METADATA) # RHEL-6
	@echo "Bug:             537088" >> $(METADATA) # RHEL-6
	@echo "Bug:             540758" >> $(METADATA) # RHEL-6
	@echo "Bug:             549503" >> $(METADATA) # RHEL-6
	@echo "Bug:             618329" >> $(METADATA) # RHEL-6
	@echo "Bug:             621061" >> $(METADATA) # RHEL-6
	@echo "Bug:             753039" >> $(METADATA) # RHEL-5
	@echo "Bug:             966203" >> $(METADATA) # RHEL-6
	@echo "Bug:             1055634" >> $(METADATA) # RHEL-7
	@echo "Bug:             1117368" >> $(METADATA) # RHEL-7
	@echo "Bug:             1117710" >> $(METADATA) # RHEL-7
	@echo "Bug:             1146491" >> $(METADATA) # RHEL-7
	@echo "Bug:             1288565" >> $(METADATA) # RHEL-6
	@echo "Bug:             1363977" >> $(METADATA) # RHEL-7
	@echo "Bug:             1375963" >> $(METADATA) # RHEL-7
	@echo "Bug:             1390669" >> $(METADATA) # RHEL-7
	@echo "Bug:             1418441" >> $(METADATA) # RHEL-7
	@echo "Bug:             1431236" >> $(METADATA) # RHEL-6
	@echo "Bug:             1536690" >> $(METADATA) # RHEL-7
	@echo "Bug:             1540004" >> $(METADATA) # RHEL-7
	@echo "Bug:             1542283" >> $(METADATA) # RHEL-7
	@echo "Bug:             1576730" >> $(METADATA) # RHEL-8
	@echo "Bug:             1588884" >> $(METADATA) # RHEL-7
	@echo "Bug:             1842897" >> $(METADATA) # RHEL-8
	@echo "Bug:             1896424" >> $(METADATA) # RHEL-8
	@echo "Bug:             1896595" >> $(METADATA) # RHEL-8
	@echo "Bug:             1899141" >> $(METADATA) # RHEL-8
	@echo "Bug:             1932752" >> $(METADATA) # RHEL-9
	@echo "Bug:             1951323" >> $(METADATA) # Fedora 33
	@echo "Bug:             1961728" >> $(METADATA) # RHEL-8
	@echo "Bug:             1965985" >> $(METADATA) # RHEL-8
	@echo "Bug:             1965989" >> $(METADATA) # RHEL-9
	@echo "Bug:             1965989" >> $(METADATA) # Fedora rawhide

	rhts-lint $(METADATA)

