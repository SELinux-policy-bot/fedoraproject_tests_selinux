# SELinux tests

This repository contains set of test for SELinux kernel, userspace and policy.
Tests are written using [beakerlib](https://github.com/beakerlib/beakerlib) with [TMT Metadata Specification](https://tmt.readthedocs.io/en/latest/spec.html).


## Gating Guidelines
Test tiers define a test's priority for our **gating process**.

* **`tier: 1`**: Critical tests that must pass for any code merge. 
* **`tier: 2`**: Important but non-critical tests.
* **`tier: 3`**: Non-critical tests.

All other tier metadata (e.g., `tag:Tier1`) is now deprecated.

## Plans

    $ tmt plans
    Found 5 plans: /plans/ci, /plans/reboot, /plans/tier1, /plans/tier2 and /plans/tier3.

## Usage

Run `tier1` on `localhost`:

    # tmt run provision -h local prepare plans -n /plans/tier1 discover execute
    # tmt run -l report -h display -v
