#!/usr/bin/python3

import selinux
try:
    selinux.matchpathcon("/dev", 16384)
except FileNotFoundError as e:
    print(e)

