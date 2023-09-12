# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/selinux-policy/Regression/pcp-daemons-and-similar
#   Description: the services were running as initrc_t, now they are confined by SELinux
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

export TEST=/CoreOS/selinux-policy/Regression/pcp-daemons-and-similar
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
	@echo "Description:     the services were running as initrc_t, now they are confined by SELinux" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        90m" >> $(METADATA)
	@echo "RunFor:          selinux-policy" >> $(METADATA)
	@echo "RunFor:          pcp" >> $(METADATA)
	@echo "Requires:        audit libselinux libselinux-utils policycoreutils selinux-policy selinux-policy-targeted /usr/sbin/service setools-console glib2 pcp pcp-manager pcp-pmda-dm pcp-webapi" >> $(METADATA)
	@echo "RhtsRequires:    library(selinux-policy/common)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Environment:     AVC_ERROR=+no_avc_check" >> $(METADATA)
	@echo "Releases:        -RHEL4" >> $(METADATA)
	@echo "Bug:             1028598" >> $(METADATA) # RHEL-7
	@echo "Bug:             1061159" >> $(METADATA) # RHEL-7
	@echo "Bug:             1064233" >> $(METADATA) # RHEL-7
	@echo "Bug:             1072785" >> $(METADATA) # RHEL-7
	@echo "Bug:             1089912" >> $(METADATA) # RHEL-6
	@echo "Bug:             1130606" >> $(METADATA) # RHEL-6
	@echo "Bug:             1130934" >> $(METADATA) # RHEL-6
	@echo "Bug:             1167825" >> $(METADATA) # RHEL-7
	@echo "Bug:             1196926" >> $(METADATA) # RHEL-7
	@echo "Bug:             1203153" >> $(METADATA) # RHEL-6
	@echo "Bug:             1206525" >> $(METADATA) # RHEL-7
	@echo "Bug:             1211520" >> $(METADATA) # RHEL-7
	@echo "Bug:             1213709" >> $(METADATA) # RHEL-7
	@echo "Bug:             1213740" >> $(METADATA) # RHEL-7
	@echo "Bug:             1252341" >> $(METADATA) # RHEL-7
	@echo "Bug:             1261811" >> $(METADATA) # RHEL-7
	@echo "Bug:             1271998" >> $(METADATA) # RHEL-7
	@echo "Bug:             1286234" >> $(METADATA) # RHEL-7
	@echo "Bug:             1309883" >> $(METADATA) # RHEL-7
	@echo "Bug:             1379371" >> $(METADATA) # RHEL-7
	@echo "Bug:             1770123" >> $(METADATA) # RHEL-7
	@echo "Bug:             1886369" >> $(METADATA) # RHEL-8

	rhts-lint $(METADATA)

