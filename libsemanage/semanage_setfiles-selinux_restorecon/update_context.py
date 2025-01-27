#!/usr/bin/env python3

import sys
import selinux
import seobject

def update_context(file_dir, new_context):
    suffix = '(/.*)?'
    trans = seobject.semanageRecords('targeted')
    trans.start()

    fcon = seobject.fcontextRecords(trans)
    fcon.add(
            file_dir + suffix,
            new_context, '', 's0', '')
    trans.finish()
    selinux.restorecon(file_dir, True, True, True)


if __name__ == "__main__":
    update_context(sys.argv[1], sys.argv[2])
