#!/usr/bin/perl -w
use DBI;
use strict; 

my $dbhost=$ARGV[0] || die "Usage: (IP or hostname) (initial database) (database username)\n";
my $dbname=$ARGV[1] || 'postgres';
my $dbuser=$ARGV[2] || 'postgres';
my $dbpass=$ARGV[3] || '';

my $status; 

### Thresholds ###
# Warn or Critical if less than this number of free connections are found
my $warn_count_free_conn=25;
my $crit_count_free_conn=10;

# Warn or Critical is less than this percentage of connections are available
my $warn_pct_free_conn=20;  
my $crit_pct_free_conn=10;


#Connect to Database, if we can't connect exit with UNKNOWN state
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sql_max="SHOW max_connections;";
my $sql_curr="SELECT COUNT(*) FROM pg_stat_activity;";
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
#while (($conn) = $sth_curr->fetchrow()) {
#	$curr_conn=$conn;
#}
my $avail_conn=$max_conn-$curr_conn;
my $avail_pct=$avail_conn/$max_conn*100;
my $used_pct=sprintf("%2.1f", $curr_conn/$max_conn*100);

if ($avail_pct < $warn_pct_free_conn || $avail_conn < $warn_count_free_conn)
{
	$status=2;
}
elsif ($avail_pct < $crit_pct_free_conn || $avail_conn < $crit_count_free_conn)
{
	$status=1;
}
elsif ($avail_pct > $warn_pct_free_conn && $avail_conn > $warn_count_free_conn)
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

if ($max_conn >= 0 && defined $curr_conn)
{
	print "$curr_conn of $max_conn Connections Used ($used_pct%)\n";
}
else
{
	print "ERROR - Unable to determine maximum number of connections. Verify connectivity and access.\n";
}
exit $status;

