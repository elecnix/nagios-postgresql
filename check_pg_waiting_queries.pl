#!/usr/bin/perl -w
#use strict;
use DBI;
use Getopt::Long;

sub usage {
    my $message = $_[0];
    if (defined $message && length $message) {
        $message .= "\n\n"
            unless $message =~ /\n$/;
    } else {
        $message = '';
    }
    print STDERR (
        $message,
        "Usage:  $0 [OPTIONS]\n" . 
        "\n" .
        "  -H,  --hostname=ADDRESS  (IP or hostname)\n" .
        "  -d,  --database=STRING   (database name)\n" .
        "  -U,  --username=STRING   (database username)\n" .
        "  -p,  --password=STRING   (database password)\n"
    );
    die("\n")
}

my %ARGS = ();

GetOptions ("H|hostaddress=s"            => \$ARGS{hostaddress},
            "D|database=s"               => \$ARGS{database},
            "U|username=s"               => \$ARGS{username},
            "p|password=s"               => \$ARGS{password},          
            'help'                       => \$ARGS{help}) or usage();

if ( $ARGS{help} ) {
    usage("")
}

my $dbhost=$ARGS{hostaddress} || usage("Required argument: -H, --hostname=ADDRESS");
my $dbname=$ARGS{database}    || 'postgres'; # you may use template1?
my $dbuser=$ARGS{username}    || 'postgres';
my $dbpass=$ARGS{password}    || '';

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
