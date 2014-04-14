#!/usr/bin/perl -w
#use strict;
use DBI;

my $dbhost=$ARGV[0] || die "Usage: (IP or hostname) (initial database) (database username)\n";
my $dbname=$ARGV[1] || 'postgres';
my $dbuser=$ARGV[2] || 'postgres';
my $dbpass=$ARGV[3] || '';

my $status;
my $msg;

#init variables
my $query_output ='';
my ($load,$lload);
my $output="";
my $query=0;
my $waiting_count=0;
my $connections;


my $sql="SELECT datname
    , procpid
    , usename
    , query_start::timestamp(0)
    , NOW()::timestamp(0)-query_start::timestamp(0) as run_time
    , (CASE WHEN l.granted IS NOT NULL THEN TRUE ELSE FALSE END) AS waiting
    , current_query
  FROM pg_stat_activity AS p 
  LEFT JOIN pg_locks AS l ON (l.pid=p.procpid AND granted != TRUE) 
  ORDER BY datname
  ";

#Connect to $dbhost
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sth = $Dbh->prepare($sql);
$sth->execute();
while (my ($datname,$pid,$username,$start_time,$run_time,$waiting,$current_query)= $sth->fetchrow()) 
{
	if ($current_query)
	{
		$connections++;
		if (($current_query !~ /\<IDLE\>/i) && ($waiting eq 1))
		{
			$msg.="($pid) $username @ $datname [$run_time],";
			$waiting_count++;
		}
	}
}
$sth->finish();

if ($waiting_count && $waiting_count >= 0)
{
	print "$waiting_count queries waiting. $msg\n";
	$status=2;
}
elsif ( $connections >= 0 )
{
	print "No queries waiting\n";
	$status=0;
}
else
{
	$status=3;
}
exit $status;
