#!/usr/bin/perl -w
use strict;
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
        "  -p,  --password=STRING   (database password)\n" .
        "\n" .
        "\n" .
        "  -s,  --slow-query-time       (Time interval of slow querys found [default: '5 minutes'])\n" .
        "  -w,  --warning-count-querys  (Warn  [default: 1])\n" .
        "  -c,  --critical-count-querys (Critical  [default: 3])\n"
    );
    die("\n")
}

my %ARGS = ();

GetOptions ("H|hostaddress=s"            => \$ARGS{hostaddress},
            "D|database=s"               => \$ARGS{database},
            "U|username=s"               => \$ARGS{username},
            "p|password=s"               => \$ARGS{password},
            "s|slow-query-time=s"        => \$ARGS{slow_query_time},
            "W|warning-count-querys=i"   => \$ARGS{warning_count_querys},
            "C|critical-count-querys=i"  => \$ARGS{critical_count_querys},            
            'help'                       => \$ARGS{help}) or usage();

if ( $ARGS{help} ) {
    usage("")
}

my $dbhost=$ARGS{hostaddress} || usage("Required argument: -H, --hostname=ADDRESS");
my $dbname=$ARGS{database}    || 'postgres'; # you may use template1?
my $dbuser=$ARGS{username}    || 'postgres';
my $dbpass=$ARGS{password}    || '';

# Warn if count slow querys more than 1
my $warn_count_querys=$ARGS{warning_count_querys}  || 1;

# Critical slow querys more than 3
my $crit_count_querys=$ARGS{critical_count_querys} || 3;

# Use postgresql interval descriptions here
# in the format of INTERVAL '$slow_interval'
# Examples:
#    10 seconds
#    15 minutes
#    4 hours
my $slow_interval = $ARGS{slow_query_time} || "5 minutes"; 

#Default to Unknown Status
my $status=3;

my $vacuum_count=0;
my $alter_count=0;
my $update_count=0;
my $insert_count=0;
my $select_count=0;
my $longidle_count=0;
my $idle_count=0;
my $drop_count=0;
my $create_count=0;
my $truncate_count=0;
my $unknown_count=0;
my $resting_count=0;
my $copy_count=0;

my $count=0; #count of queries of interest
my $total_count; # total number of connections
my $nonidle_count; 
my $detail=0;
my $short_query;

my $msg='';
my $msg_query_details='';
my $msg_counts='';

#Connect to Database
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sql="SELECT datname,current_query,(((timeofday()::TIMESTAMP)-query_start)) AS duration, (CASE WHEN timeofday()::TIMESTAMP-query_start > INTERVAL '$slow_interval' THEN TRUE ELSE FALSE END) AS slow,usename FROM pg_stat_activity();";

my $sth = $Dbh->prepare($sql);
$sth->execute() || print "CRITICAL! Unable to run query, got: $DBI::errstr";
while (my ($datname,$query,$duration,$slow,$username) = $sth->fetchrow()) 
{
	print "$username\@$datname -> $query\n";
	if ($slow =~ /1/i)
	{
		if ($query =~/\<IDLE\>/i)
		{
			$longidle_count++;
		}
		else
		{
			$detail=1;
		}
	}

#Try to categorize queries
	if ($query =~/^SELECT/i)
	{
		$select_count++;
	}
	elsif ( ($query =~/\<IDLE\>/i) || (length($query) == 0) )
	{
		$idle_count++;
	}
	elsif ($query =~/^INSERT/i)
	{
		$insert_count++;
	}
	elsif ($query =~/^UPDATE/i)
	{
		$update_count++;
		$detail=1;
	}
	elsif ($query =~/^VACUUM/i)
	{
		$vacuum_count++;
		$detail=1;
	}
	elsif ($query =~/^CREATE/i)
	{
		$create_count++;
		$detail=1;
	}
	elsif ($query =~/^DROP/i)
	{
		$drop_count++;
		$detail=1;
	}
	elsif ($query =~/^TRUNCATE/i)
	{
		$truncate_count++;
		$detail=1;
	}
	elsif ($query =~/^ALTER/i)
	{
		$alter_count++;
		$detail=1;
	}
	elsif ($query =~/^COPY/i)
	{
		$copy_count++;
		$detail=1;
	}
# I was attempting to catch any queries with no status, apparently it isn't working
# The $query field looks like a bunch of spaces. I speculate this is happening
# when a client has just connected or finished a query and is not yet in the IDLE state.
# I call this "resting" -- right before IDLE.
	elsif ($query =~/[\t\s]/)
	{
		$resting_count++;
	}
	else
	{
		$unknown_count++;
		$detail=1;
	}

# if detail is set we do stuff
	if ($detail==1)
	{
		$detail=0;
		$count++;
		# Trim the query since Nagios can only report so much of it.
		$short_query=substr($query,0,18);
		# Trim duration by 5 digits also
		$duration=substr($duration,0,length($duration)-5);
		$msg_query_details .= " ,$username doing $short_query on $datname for $duration";
	}
	$total_count++;
}
$Dbh->disconnect;

if ($total_count)
{
	$nonidle_count=$total_count-$idle_count;
}

# 0 OK
# 1 WARNING
# 2 CRITICAL
# 3 UNKNOWN

if ($count > $crit_count_querys)
{
	$status=2;
}
elsif ($count > $warn_count_querys)
{
	$status=1;
}
elsif ($total_count && $total_count >= 0)
{
	$status=0;
}
else
{
	$status=3;
}

if ($longidle_count > 0)
{
	$msg_counts="$longidle_count long IDLEs $msg_counts";
}
if ($resting_count > 0)
{
	$msg_counts="$resting_count resting $msg_counts";
}

if ($select_count > 0)
{
	$msg_counts="$select_count SELECTs $msg_counts";
}

if ($insert_count > 0)
{
	$msg_counts="$insert_count INSERTs $msg_counts";
}

if ($update_count > 0)
{
	$msg_counts="$update_count UPDATEs $msg_counts";
}

if ($vacuum_count > 0)
{
	$msg_counts="$vacuum_count VACUUMs $msg_counts";
}

if ($alter_count > 0)
{
	$msg_counts="$alter_count ALTERs $msg_counts";
}

if ($drop_count > 0)
{
	$msg_counts="$drop_count DROPs $msg_counts";
}

if ($create_count > 0)
{
	$msg_counts="$create_count CREATEs $msg_counts";
}

if ($truncate_count > 0)
{
	$msg_counts="$truncate_count TRUNCATEs $msg_counts";
}
if ($copy_count > 0)
{
	$msg_counts="$copy_count COPYs $msg_counts";
}

if (length($msg_counts) > 1)
{
	$msg_counts="($msg_counts)";
}

if ($total_count && $total_count >= 0)
{
	print "$nonidle_count of $total_count connections are active $msg_counts $msg_query_details\n";
}
else
{
        print "Error - Verify connectivity and access\n";
}
exit $status;
