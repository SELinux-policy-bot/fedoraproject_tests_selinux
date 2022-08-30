#!/bin/bash

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    return 0
}

# called by dracut
install() {
    inst_hook pre-pivot 50 "$moddir/relabel.sh"
    inst_multiple setfiles getfattr
}
