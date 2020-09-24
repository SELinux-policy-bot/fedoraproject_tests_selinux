#!/usr/bin/python3
from selinux import get_default_context_with_rolelevel

context='system_u:system_r:crond_t:s0-s0:c1000.c1001,c1003.c1004,c1006.c1007,c1023'
user='system_u'
role='system_r'
(ret, result) = get_default_context_with_rolelevel(user, role, None, context)

print("Return value: ", ret)
print("Result: ", result )

if ret == 0:
    if result and (not result.startswith("system_u:system_r:system_cronjob_t")):
        print("Unexpected result: ", result)
        exit(1)
else:
    print("Failed to get default context!")
    exit(ret)
