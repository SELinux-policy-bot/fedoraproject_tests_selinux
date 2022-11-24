#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/selinux-policy/Regression/rsyslog-and-similar
#   Description: Test coverage for SELinux AVC issues  with rsyslog in various configurations
#   Author: Amith Kumar <apeetham@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="selinux-policy"

function custom_policy() {
cat > rsyslog_imfile_policy.te << EOF
module rsyslog_imfile_policy 1.0;

require {
    type syslogd_t;
    attribute non_security_file_type;
    class dir { read search };
}

dontaudit syslogd_t non_security_file_type:dir { read search };

EOF
make -f /usr/share/selinux/devel/Makefile rsyslog_imfile_policy.pp
semodule -i rsyslog_imfile_policy.pp
}

function update_rsys() {
cat >> /etc/rsyslog.conf << EOF

module(load="imfile")

input(type="imfile"
        File="/var/www/product/logs/access.log"
        Tag="product"
        Severity="info"
        Facility="local6")

EOF
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport 'selinux-policy/common'"
        rlSESatisfyRequires
        rlAssertRpm ${PACKAGE}
        rlAssertRpm ${PACKAGE}-targeted
        rlAssertRpm rsyslog
        rlAssertRpm rsyslog-gnutls
        rlServiceStop rsyslog
        rlSESetEnforce
        rlSEStatus
        rlRun "custom_policy"
        rlSESetTimestamp
        sleep 2
    rlPhaseEnd

    rlPhaseStartTest "rsyslog imfile module cannot read parent directories of the file to process bz#1823669"
        rlRun "cp -rv /etc/rsyslog.conf /etc/rsyslog.conf-orig"
        tst_Time="$(date '+%T')"
	rlRun "mkdir -p /var/www/product/logs"
        rlRun "restorecon -Frv /var/www"
        rlRun "update_rsys"
        rlRun "systemctl restart rsyslog"
        sleep 3
        rlRun "ausearch -m AVC --start $tst_Time --input-logs" 1
        rlRun "cp -rv /etc/rsyslog.conf-orig /etc/rsyslog.conf"
        rlRun "systemctl restart rsyslog"
    rlPhaseEnd

    rlPhaseStartTest "rsyslog omfile cannot append to custom file locations bz#1823672"
        rlRun "setsebool logging_syslogd_append_public_content on"
        rlRun "cp -rv /etc/rsyslog.conf /etc/rsyslog.conf-orig"
        tst_Time="$(date '+%T')"
        rlRun "mkdir -p /my/custom/log"
        rlRun "touch /my/custom/log/file"
        rlRun 'semanage fcontext -a -t public_content_rw_t "/my/custom(/.*)?"'
        rlRun "restorecon -Frv /my"
        rlRun "echo ' ' >> /etc/rsyslog.conf"
        rlRun "echo '*.info;mail.none;authpriv.none;cron.none                /my/custom/log/file' >> /etc/rsyslog.conf"
        rlRun "echo ' ' >> /etc/rsyslog.conf"
        rlRun "systemctl restart rsyslog"
        sleep 3
        rlRun "ausearch -m AVC --start $tst_Time --input-logs" 1
        rlRun 'semanage fcontext -d -t public_content_rw_t "/my/custom(/.*)?"'
        rlRun "semodule -r rsyslog_imfile_policy"
        rlRun "cp -rv /etc/rsyslog.conf-orig /etc/rsyslog.conf"
        rlRun "systemctl restart rsyslog"
        rlRun "setsebool logging_syslogd_append_public_content off"
    rlPhaseEnd

    rlPhaseStartCleanup
        sleep 2
        rlSECheckAVC
        rlRun "rm -rf /var/www/product /my /etc/rsyslog.conf-orig"
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd
