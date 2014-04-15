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
        "  -w,  --warning-exlocks   (Warn if Exclusive Locks greater than this number [default: 5])\n" .
        "  -c,  --critical-exlocks  (Critical if Exclusive Locks greater than this number [default: 10])\n"
    );
    die("\n")
}

my %ARGS = ();

GetOptions ("H|hostaddress=s"   => \$ARGS{hostaddress},
            "D|database=s"      => \$ARGS{database},
            "U|username=s"      => \$ARGS{username},
            "p|password=s"      => \$ARGS{password},
            "W|warning-pct=i"   => \$ARGS{warning_exlocks},
            "C|critical-pct=i"  => \$ARGS{critical_exlocks},            
            'help'              => \$ARGS{help}) or usage();

if ( $ARGS{help} ) {
    usage("")
}

my $dbhost=$ARGS{hostaddress} ||  usage("Required argument: -H, --hostname=ADDRESS");
my $dbname=$ARGS{database}    || 'postgres';
my $dbuser=$ARGS{username}    || 'postgres';
my $dbpass=$ARGS{password}    || '';

my $warn_count_exlocks=$ARGS{warning_exlocks}  || 5;
my $crit_count_exlocks=$ARGS{critical_exlocks} || 10;

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

if ($exlocks > $crit_count_exlocks)
{
	$status=2;
}
elsif ($exlocks > $warn_count_exlocks)
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
