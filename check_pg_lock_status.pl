#!/usr/bin/perl -w
use DBI;
use strict;

my $dbhost=$ARGV[0] || die "Usage: (IP or hostname) (initial database) (database username)\n";
my $dbname=$ARGV[1] || 'postgres';  # you may use template1?
my $dbuser=$ARGV[2] || 'postgres';
my $dbpass=$ARGV[3] || '';

#Default to Unknown Status
my $status=3;

my $locks=0;
my $exlocks=0; #exclusive locks
my $msg="";

#Connect to Database
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sql="SELECT mode,COUNT(mode) FROM pg_locks WHERE relation IS NOT NULL OR database IS NOT NULL GROUP BY mode ORDER BY mode;";
my $sth = $Dbh->prepare($sql);
$sth->execute();
while (my ($mode,$count) = $sth->fetchrow()) 
{
	# TODO: We could get fancy here and only wory about Exclusive Locks on certain tables.
	# Do not worry about RowExclusiveLocks, just ExclusiveLocks
	if ($mode =~ /^exclusive/i) {
		$exlocks=$exlocks+$count;
	}
	$locks=$locks+$count;
	$msg="$msg $mode($count),";
}

if ($exlocks > 10)
{
	$status=2;
}
elsif ($exlocks > 5)
{
	$status=1;
}
elsif ($exlocks >= 0)
{
	$status=0;
}
else
{
	$status=3;
}

# 0 OK
# 1 WARNING
# 2 CRITICAL
# 3 UNKNOWN

if ($exlocks >= 0)
{
	print "$locks Locks -- $msg\n";
}
else
{
	print "Error - Verify connectivity and access.\n";
}

exit $status;
