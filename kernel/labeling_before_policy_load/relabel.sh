#!/bin/bash

function dumpcon() {
	getfattr --only-values -n security.selinux "$@" | tr -d '\000'
	echo
}

mount -o remount,rw /sysroot
dumpcon /sysroot/etc >/sysroot/etc/labeldump
echo test > /sysroot/etc/testfile
dumpcon /sysroot/etc/testfile >>/sysroot/etc/labeldump
setfiles -vF -r /sysroot \
	/sysroot/etc/selinux/targeted/contexts/files/file_contexts \
	/sysroot/etc
dumpcon /sysroot/etc/testfile >>/sysroot/etc/labeldump
