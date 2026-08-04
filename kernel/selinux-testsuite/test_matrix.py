#!/usr/bin/python3
#
# Runs /kernel/selinux-testsuite on all supported platforms via Testing Farm
#
# You need to pass RH ranch TF API token to the script - see below.
#
# Usage: TESTING_FARM_API_TOKEN=... ./test_matrix.py <GIT_URL> <GIT_BRANCH>
#

import requests
import json

def build_compose(compose, arches=['x86_64', 'aarch64', 'ppc64le', 's390x']):
    for arch in arches:
        yield { "arch": arch, "os": { "compose": compose } }

def build_environments():
    # Fedora
    # known issue - Beaker provisioning fails
    yield from build_compose('Fedora-Rawhide', arches=['x86_64'])
    # known issue - wrong variant in Beaker
    yield from build_compose('Fedora-eln', arches=['x86_64'])
    # known issue - provisioning fails for non-x86_64
    yield from build_compose('Fedora-45', arches=['x86_64'])
    yield from build_compose('Fedora-44')
    yield from build_compose('Fedora-43')

    # CentOS Stream
    yield from build_compose('CentOS-Stream-10')
    yield from build_compose('CentOS-Stream-9')

    # RHEL 10
    yield from build_compose('RHEL-10.3-Nightly')
    yield from build_compose('RHEL-10.2-Nightly')
    yield from build_compose('RHEL-10.0-Nightly')

    # RHEL 9
    yield from build_compose('RHEL-9.9.0-Nightly')
    yield from build_compose('RHEL-9.8.0-Nightly')
    yield from build_compose('RHEL-9.6.0-Nightly')
    yield from build_compose('RHEL-9.4.0-Nightly')
    yield from build_compose('RHEL-9.2.0-Nightly')

    # RHEL 8
    yield from build_compose('RHEL-8.10.0-Nightly')
    yield from build_compose('RHEL-8.8.0-Nightly')
    yield from build_compose('RHEL-8.6.0-Nightly')
    # Only x86_64 is supported
    yield from build_compose('RHEL-8.4.0-Nightly', arches=['x86_64'])

    # RHEL 7
    yield from build_compose('RHEL-7.9-Nightly', arches=['x86_64', 'ppc64', 'ppc64le', 's390x'])

def build_request(tmt_url, tmt_ref):
    return {
        "test": {
            "tmt": {
                "url": tmt_url,
                "ref": tmt_ref,
                "test_name": "/kernel/selinux-testsuite",
                "name": "/plans/tier1",
            }
        },
        "environments": list(build_environments()),
        "settings": {
            "pipeline": { "parallel-limit": 20 }
        },
    }

def tf_request_test(tf_api_token, request):
    print(request)
    headers = { 'Authorization': f'Bearer {tf_api_token}' }
    res = requests.post('https://api.testing-farm.io/v0.1/requests',
                        headers=headers, json=request).json()
    if 'detail' in res:
        err = res['detail'][0]
        raise RuntimeError(f'{err["type"]}: {err["msg"]} ({".".join(err["loc"])})')
    return res["id"]

if __name__ == '__main__':
    import os
    import sys

    tf_api_token = os.environ['TESTING_FARM_API_TOKEN']
    req_id = tf_request_test(tf_api_token, build_request(sys.argv[1], sys.argv[2]))
    print(f'https://api.testing-farm.io/v0.1/requests/{req_id}')
