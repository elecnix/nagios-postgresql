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

#Initialize all the remote time values as global
my ($status, $msg, $version, $rymd, $rhms, $rhour, $rmin, $rsec, $rses, $rtime);

#Connect to Database and fetch the remote time. 
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sql="SELECT NOW(),VERSION();";
my $sth = $Dbh->prepare($sql);
$sth->execute();
while (my ($time,$pgversion) = $sth->fetchrow()) {
	$version=$pgversion;
	#2005-03-02 08:08:52.174051-07
	($rymd,$rhms)=split /[\s]/, $time;
	($rhour,$rmin,$rsec)=split /[:]/, $rhms;
	($rsec,undef)=split /[.]/, $rsec;
	($rtime,undef)=split /[.]/, $time;

}

#Setup time variables
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time()); # The time now...
my $fullyear = $year + 1900; # The current year is exactly 'num yrs since 1900.'
$year = substr ($year,2,3);
$year = sprintf("%02d", $year);
$mday  = sprintf("%02d", $mday);   # Make sure we have two digits.
$mon   = sprintf("%02d", ++$mon); # Ditto here...
$sec   = sprintf("%02d", $sec);   # Ditto here...
$min   = sprintf("%02d", $min);   # Ditto here...
$hour  = sprintf("%02d", $hour);  # Ditto here...
$yday  = sprintf("%03d", $yday);  # 3 digits here...
my $ltime = "$fullyear-$mon-$mday $hour:$min:$sec";
my $lymd="$fullyear-$mon-$mday";

# Reporting 
# TODO: This could be a lot cleaner if we required more perl time modules
if ($lymd ne $rymd)
{
	$status=2;
	$msg="CRITIAL: Date is off! REMOTE: $rtime LOCAL: $ltime - $version\n";
}
elsif ($hour ne $rhour)
{
	$status=2;
	$msg="WARNING: Hour is off! REMOTE: $rtime LOCAL: $ltime - $version\n";
}
elsif ($min ne $rmin)
{
	$status=1;
	$msg="WARNING: Minute is off! REMOTE: $rtime LOCAL: $ltime - $version\n";
}
elsif ($sec ne $rsec)
{
	$status=0;
	$msg="Time is close REMOTE: $rtime LOCAL: $ltime - $version\n";
}
elsif ($sec eq $rsec)
{
	$status=0;
	$msg="Time in sync REMOTE: $rtime LOCAL: $ltime - $version\n";
}
else
{
	$status=3;
	$msg="Error - Verify connectivity and access\n";
}

# 0 OK
# 1 WARNING
# 2 CRITICAL
# 3 UNKNOWN

print $msg;
exit $status;

