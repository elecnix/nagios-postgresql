#!/usr/bin/perl -w
use DBI;
use strict;
use Nagios::Plugin; # may be Monitoring::Plugin

my $np = Nagios::Plugin->new(
	usage => "Usage: -H (IP or hostname) [-d (initial database)] [-U (database username)] [-P (database password)]\n",
	version => "0.2",
	url => "https://github.com/elecnix/nagios-postgresql",
);

$np->add_arg(
	spec => 'hostname|H=s',
	help => "IP or hostname",
	required => 1,
);
$np->add_arg(
	spec => 'database|d=s',
	help => "initial database (default %s)",
	default => 'postgres',
);
$np->add_arg(
	spec => 'username|U=s',
	help => "database username (default %s)",
	default => 'postgres',
);
$np->add_arg(
	spec => 'password|P=s',
	help => "database password",
);
$np->add_arg(
	spec => 'warning|w=s',
	help => [
		'Exit with WARNING status if less than COUNT connections are free',
		'Exit with WARNING status if less than PERCENT connections are free',
	],
	label => [ 'COUNT', 'PERCENT%' ],
	default => "25%",
);
$np->add_arg(
	spec => 'critical|c=s',
	help => [
		'Exit with ERROR status if less than COUNT connections are free',
		'Exit with ERROR status if less than PERCENT connections are free',
	],
	label => [ 'COUNT', 'PERCENT%' ],
	default => 10,
);

$np->getopts;

my $dbhost=$np->opts->hostname;
my $dbname=$np->opts->database;
my $dbuser=$np->opts->username;
my $dbpass=$np->opts->password;

#Connect to Database, if we can't connect exit with UNKNOWN state
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sql_max="SHOW max_connections;";
my $sql_curr="SELECT COUNT(*) FROM pg_stat_activity();";
my $sth_max = $Dbh->prepare($sql_max);
my $sth_curr = $Dbh->prepare($sql_curr);
$sth_max->execute() || print "CRITICAL! Unable to run query, got: $DBI::errstr";;
my @row_max = $sth_max->fetchrow_array;
my $max_conn = $row_max[0];
#while (($mconn) = $sth_max->fetchrow()) {
#	$max_conn=$mconn;
#}
$sth_curr->execute() || print "CRITICAL! Unable to run query, got: $DBI::errstr";
my @row_curr = $sth_curr->fetchrow_array;
my $curr_conn = $row_curr[0];

if(not defined $curr_conn)
{
	$np->nagios_die("Unable to determine maximum number of connections. Verify connectivity and access.\n");
}

my $warning = $np->opts->warning;
if ($warning =~ /^\d+%$/) {
	$warning =~ s/%//;
	$warning = $max_conn - $max_conn / 100 * $warning;
	warn("Calculated threshold (from percentage): warn=>$warning\n") if ($np->opts->verbose);
} else {
	$warning = $max_conn - $warning;
	warn("Calculated threshold (from value): warn=>$warning\n") if ($np->opts->verbose);
}
my $critical = $np->opts->critical;
if ($critical =~ /^\d+%$/) {
	$critical =~ s/%//;
	$critical = $max_conn - $max_conn / 100 * $critical;
	warn("Calculated threshold (from percentage): crit=>$critical\n") if ($np->opts->verbose);
} else {
	$critical = $max_conn - $critical;
	warn("Calculated threshold (from value): crit=>$critical\n") if ($np->opts->verbose);
}

$np->add_perfdata(
	label => 'connections',
	value => $curr_conn,
	warning => $warning,
	critical => $critical,
	max => $max_conn,
);

if ($max_conn >= 0)
{
	my $used_pct=sprintf("%2.1f", $curr_conn/$max_conn*100);
	$np->nagios_exit(
		return_code => $np->check_threshold(
			check => $curr_conn,
			warning => $warning,
			critical => $critical,
		),
		message => "$curr_conn of $max_conn Connections Used ($used_pct%)",
	);
}
else
{
	$np->nagios_die("Unable to determine maximum number of connections. Verify connectivity and access.");
}
