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
        "  -w,  --warning-xid-m     (Warn if max xid is greater equal than this number [default: 1500])\n" .
        "  -c,  --critical-xid-m    (Critical if max xid is greater equal than this number [default: 1700])\n"
    );
    die("\n")
}

my %ARGS = ();

GetOptions ("H|hostaddress=s"     => \$ARGS{hostaddress},
            "D|database=s"        => \$ARGS{database},
            "U|username=s"        => \$ARGS{username},
            "p|password=s"        => \$ARGS{password},
            "W|warning-xid-m=i"   => \$ARGS{warning_xid_m},
            "C|critical-xid-m=i"  => \$ARGS{critical_xid_m},            
            'help'                => \$ARGS{help}) or usage();

if ( $ARGS{help} ) {
    usage("")
}

my $dbhost=$ARGS{hostaddress} ||  usage("Required argument: -H, --hostname=ADDRESS");
my $dbname=$ARGS{database}    || 'postgres';
my $dbuser=$ARGS{username}    || 'postgres';
my $dbpass=$ARGS{password}    || '';

#=================
# Configuration
#=================
# 2000M = 2 Billion

# Wrap at 2 Billion
my $wrap_xid_M=2000;

# Warn at 1.5 Billion
my $warn_xid_M=$ARGS{warning_xid_m}  || 1500;

# Critical at 1.7 Billion
my $crit_xid_M=$ARGS{critical_xid_m} || 1700;

#Variables
my $max_xid_pct=-99; # default to a negative percentage
my $max_xid_datname="NOT SET (script broke)";
my $max_xid_M=-9999; # default to negative XID #
my $err='';

#Default to Unknown Status
my $status=3;

#=================
# Connect to Database
#=================
my $Con = "DBI:Pg:dbname=$dbname;host=$dbhost";
my $Dbh = DBI->connect($Con, $dbuser, $dbpass, {RaiseError => 0, PrintError => 0}) || die "Unable to access Database '$dbname' on host '$dbhost' as user '$dbuser'. Error returned was: ". $DBI::errstr ."";

my $sql="SELECT datname, age(datfrozenxid) FROM pg_database WHERE datallowconn != FALSE;";
my $sth = $Dbh->prepare($sql);
$sth->execute();
while (my ($datname,$max_xid) = $sth->fetchrow()) {
  #print "MAX: $max_xid -  $wrap_xid\n";
  my $xid_used_M=sprintf('%1d',($max_xid/1000000));
  my $xid_used_pct=sprintf('%1d', ($xid_used_M/$wrap_xid_M)*100);

  #find the database with the highest transaction id
  if ($xid_used_M > $max_xid_M)
  {
    #print "$datname,$xid_used_pct% used,$xid_used_millions M used xids\n";
    $max_xid_pct=$xid_used_pct;
	$max_xid_M=$xid_used_M;
	$max_xid_datname=$datname;
  }
}
$Dbh->disconnect;

#=================
# Status Processing
#=================
# 3 UNKNOWN
# 2 CRITICAL
# 1 WARNING
# 1 OK

if ($max_xid_M >= $crit_xid_M) 
{ 
	$status=2; 
}
elsif ($max_xid_M >= $warn_xid_M) 
{ 
	$status=1; 
}
elsif ($max_xid_M < $warn_xid_M && $max_xid_M >= 0 ) 
{ 
	$status=0; 
}
else
{
	#Math problems strike again! 
	$status=3; 
}

#=================
# Reporting
#=================

if ($max_xid_M >= 0)
{
	print "Transaction IDs are $max_xid_pct% used ($max_xid_M M) in database $max_xid_datname.\n";
}
else
{
	print "Error - Verify connectivity and access\n";
}

exit $status;
