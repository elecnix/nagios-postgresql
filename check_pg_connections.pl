#!/usr/bin/perl -w
use DBI;
use strict; 
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
        "  -w,  --warning-pct       (Warn if less than percent of connections are available [default: 20])\n" .
        "  -c,  --critical-pct      (Critical if less than percent of connections are available [default: 10])\n" .
        "\n" .
        "  --warning-count          (Warn if less than free connections are found [default: null])\n" .
        "  --critical-count         (Critical if less than free connections are found [default: null])\n"
    );
    die("\n")
}

my %ARGS = ();

GetOptions ("H|hostaddress=s"   => \$ARGS{hostaddress},
            "D|database=s"      => \$ARGS{database},
            "U|username=s"      => \$ARGS{username},
            "p|password=s"      => \$ARGS{password},
            "W|warning-pct=i"   => \$ARGS{warning_pct},
            "C|critical-pct=i"  => \$ARGS{critical_pct},            
            "warning-count=i"   => \$ARGS{warning_count},
            "critical-count=i"  => \$ARGS{critical_count},
            'help'              => \$ARGS{help}) or usage();

if ( $ARGS{help} ) {
    usage("")
}

my $dbhost=$ARGS{hostaddress} ||  usage("Required argument: -H, --hostname=ADDRESS");
my $dbname=$ARGS{database}    || 'postgres';
my $dbuser=$ARGS{username}    || 'postgres';
my $dbpass=$ARGS{password}    || '';

my $status; 
### Thresholds ###
# Warn or Critical if less than this number of free connections are found
my $warn_count_free_conn=$ARGS{warning_count};    #|| 25;
my $crit_count_free_conn=$ARGS{critical_count};   #|| 10;

# Warn or Critical is less than this percentage of connections are available
my $warn_pct_free_conn=$ARGS{warning_pct}   || 20;  
my $crit_pct_free_conn=$ARGS{critical_pct}  || 10;

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


if ( $warn_count_free_conn && $crit_count_free_conn ) {

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

} else {

    if ($avail_pct <= $crit_pct_free_conn)
    {
    	$status=2;
    }
    elsif ($avail_pct <= $warn_pct_free_conn)
    {
    	$status=1;
    }
    else
    {
    	$status=0;
    }

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

