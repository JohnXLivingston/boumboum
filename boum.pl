#!/usr/bin/perl

my $nb = int($ARGV[0]) || 100;
my $sleep = $ARGV[1] || '1';
my $nice = 19;

print "nb=$nb sleep=$sleep nice=$nice\n";

my $fork = "fork();" x $nb;
my $prog = <<EOF;
#include <sys/types.h>
#include <unistd.h>

int
main() {
	$fork
	while(1) {
		sleep($sleep);
	}
	return 0;
}

EOF

open(FH, '>', 'boum.c') or die $!;
print FH $prog;
close(FH);

`cc -o boum boum.c`;
`nice -$nice ./boum`;
