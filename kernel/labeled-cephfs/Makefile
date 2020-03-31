export TEST=/kernel/Regression/selinux-cephfs-labeling
export TESTVERSION=0.1

FILES=$(METADATA) runtest.sh Makefile

.PHONY: all clean

run: $(FILES)
	./runtest.sh

clean:

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Ondrej Mosnacek <omosnace@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Test for correct CephFS SELinux labeling" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        30m" >> $(METADATA)
	@echo "Requires:        openssh-server openssh-clients python3-pip ceph attr" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2+" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
