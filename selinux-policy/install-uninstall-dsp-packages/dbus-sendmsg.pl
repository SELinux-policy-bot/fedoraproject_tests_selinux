#!/usr/bin/perl -w
### Check if dbus communication is allowed bidirectionally

use strict;

my $sesearch_cmd="/usr/bin/sesearch";
my $sesearch_args="-A -c dbus -p send_msg";
my ($line, @output);
my (@seoutarray, $seout, $seline);
my $count=0;

# Take all allow rules matching the description
open SESEARCH, "$sesearch_cmd $sesearch_args |"
  or die "Cannot run sesearch: $!";
while ($line =<SESEARCH>) {
	$count++;
	#debug printf "%4d %s", $count, $line;
	chomp $line;
	# > sesearch -A -t systemd_timedated_t -s initrc_t -c dbus -p send_msg
	# allow dbusd_unconfined nsswitch_domain:dbus send_msg;
	# allow system_bus_type system_dbusd_t:dbus { acquire_svc send_msg };
	# allow NetworkManager_t xguest_t:dbus send_msg; [ xguest_connect_network ]:True
	@output = split /[ :]/, $line;
        next if $output[2] eq "self";
        next if $output[2] eq $output[1];
	# Look for the rule in the inverse direction
	open $seout, "$sesearch_cmd $sesearch_args -s $output[2] -t $output[1] |"
	  or die "Cannot run sesearch: $!";
	@seoutarray = <$seout>;
	if (@seoutarray == 0) {
	  print "No reverse match: $line\n";
	}
	else {
	  foreach $seline (@seoutarray) {
	    if ($seline =~ /\]:/) {
	      print "Conditional rule: $seline";
	      print "   Original line: $line\n";
	    }
	  }
	}
	close $seout;
}
print "Total dbus:send_msg rules number: $count\n";

__END__

State as of 2024.03.05
f39: 1738 rules, 8 asymmetrical
RHEL9: 1731 rules, 6 asymmetrical
RHEL8: 2359 rules, 52 asymmetrical

f39
No reverse match: allow cronjob_t openshift_app_t:dbus send_msg;
No reverse match: allow cronjob_t openshift_t:dbus send_msg;
No reverse match: allow cronjob_t staff_t:dbus send_msg;
No reverse match: allow cronjob_t sysadm_t:dbus send_msg;
No reverse match: allow cronjob_t user_t:dbus send_msg;
No reverse match: allow pasta_t init_t:dbus send_msg;
No reverse match: allow pasta_t system_dbusd_t:dbus send_msg;
No reverse match: allow pasta_t systemd_hostnamed_t:dbus send_msg;

RHEL9
No reverse match: allow cronjob_t openshift_app_t:dbus send_msg;
No reverse match: allow cronjob_t openshift_t:dbus send_msg;
No reverse match: allow cronjob_t staff_t:dbus send_msg;
No reverse match: allow cronjob_t sysadm_t:dbus send_msg;
No reverse match: allow cronjob_t user_t:dbus send_msg;
No reverse match: allow nvme_stas_t system_dbusd_t:dbus { acquire_svc send_msg };

RHEL8

