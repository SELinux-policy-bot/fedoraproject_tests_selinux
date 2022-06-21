#!/bin/bash

sestatus
ls -lZ /
/usr/sbin/setfiles -F /etc/selinux/targeted/contexts/files/file_contexts /
ls -lZ /

