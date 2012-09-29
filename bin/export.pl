#!/usr/local/bin/perl
use strict;
use DBI;
use YAML;
use CAM::DBF;
use Getopt::Std;
use Archive::Zip;

# Defaults.
my %def =
(
    e => 'development',
    c => 'config/database.yml',
    f => 'tmp',
);

# Options.
my %opt;
my $opt = 'he:r:c:f:';
getopts($opt, \%opt);
sub help
{
    print <<EOH;
dbf_export [$opt] [root_dir]
export a DBF file for SwissPerfect
  -r  rails root directory (default: current directory)
  -e  environment (default: $def{e})
  -c  database config file (default: $def{c})
  -f  output directory for file (default: $def{f})
  -h  print this help
examples:
  > $0 /Users/mjo/Projects/icu_ratings_app
  > $0 -e production /var/apps/ratings/current
  > $0 -e production
EOH
    exit 0;
}

# Print help and exit.
&help() if $opt{h};

# Defaults.
$opt{e} ||= $def{e};
$opt{c} ||= $def{c};
$opt{f} ||= $def{f};

# Get the optional root directory and cd into it.
my $root = $opt{r};
!$root || chdir($root) || die "cannot cd to $root\n";

# Get the current year and month.
my ($year, $mon) = &get_year_month();

# Get a handle to the database.
my $dbh = &get_dbh();

# Get the data we need from the database.
my $players = &get_players();
my $ratings = &get_ratings();

# Write the files.
my $sp_file = &export_sp();
my $sm_file = &export_sm();

# Put them both in a ZIP archive file and print the file's name.
my $zip_file = &archive();

# Finally, print the file's name (this is the success signal).
print "$zip_file\n";

#
# Helpers.
#

sub get_year_month
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime;
    ($year) = $year =~ /(\d\d)$/;
    $mon = qw/jan feb mar apr may jun jul aug sep oct nov dec/[$mon];
    die "invalid year ($year) or month ($mon)" unless $year =~ /^\d\d$/ && $mon =~ /^[a-z]{3}$/;
    ($year, $mon);
}

sub get_dbh
{
    my $cnf = $opt{c};
    die "configuration file ($cnf) does not exists\n" unless -f $cnf;
    open CNF, $cnf || die "cannot read configuration file $cnf";
    my $yml = do { local $/ = undef; <CNF> };
    close CNF;
    my $data = eval { Load($yml) };
    die "error reading configuration file ($cnf): $@\n" if $@;
    die "data from $cnf is not a hash" unless 'HASH' eq ref $data;
    my $env = $opt{e};
    my $db = $data->{$env};
    die "no $env environment in $cnf" unless 'HASH' eq ref $db;
    my $dbn  = $db->{database} || die "no database for $env environment in $cnf";
    my $user = $db->{username} || die "no username for $env environment in $cnf";
    my $pass = $db->{password};
    my $dsn = "DBI:mysql:$dbn";
    my $dbh = eval { DBI->connect($dsn, $user, $pass, { RaiseError => 1 }) };
    die sprintf("could not connect to %s: %s\n", $dbn, $@ || 'no reason') if $@ || !$dbh;
    $dbh;
}

sub get_players
{
    my $sql = <<EOS;
SELECT
  id,
  last_name,
  first_name,
  gender,
  dob,
  club,
  title,
  fed
FROM
  icu_players
WHERE
  deceased = 0 AND
  master_id IS NULL
EOS
    my $data = eval { $dbh->selectall_arrayref($sql, { Slice => {} }) };
    die sprintf("players database query failed: %s\n", $@ || 'no reason') unless 'ARRAY' eq ref $data;

    my $players = {};
    $players->{$_->{id}} = $_ for @{$data};
    $players;
}

sub get_ratings
{
    my ($sql, $data, $ids);
    my $ratings = {};

    # Latest from the rating lists.
    $sql = "SELECT icu_id, rating FROM icu_ratings ORDER BY list DESC";
    $data = eval { $dbh->selectall_arrayref($sql, { Slice => {} }) };
    die sprintf("published ratings database query failed: %s\n", $@ || 'no reason') unless 'ARRAY' eq ref $data;
    $ratings->{$_->{icu_id}} ||= $_->{rating} for @{$data};

    # Or from the legacy list if necessary.
    $ids = join(',', sort keys %{$ratings});
    $sql = "SELECT icu_id, rating FROM old_ratings WHERE icu_id NOT IN ($ids)";
    $data = eval { $dbh->selectall_arrayref($sql, { Slice => {} }) };
    die sprintf("old ratings database query failed: %s\n", $@ || 'no reason') unless 'ARRAY' eq ref $data;
    $ratings->{$_->{icu_id}} ||= $_->{rating} for @{$data};

    $ratings;
}

sub export_sp
{
    my $file = sprintf('%s/swiss_perfect.dbf', $opt{f});
    my $dbf = eval
    {
        CAM::DBF->create($file,
            {name => 'ICU_CODE',   type=>'N', length => 20, decimals => 0},
            {name => 'FIRST_NAME', type=>'C', length => 50, decimals => 0},
            {name => 'LAST_NAME',  type=>'C', length => 50, decimals => 0},
            {name => 'ICU_RATING', type=>'N', length =>  5, decimals => 0},
            {name => 'SEX',        type=>'C', length =>  1, decimals => 0},
            {name => 'CLUB',       type=>'C', length => 25, decimals => 0},
            {name => 'DOB',        type=>'C', length => 10, decimals => 0},
        );
    };
    die "cannot write file $file\n" if $@ || !$dbf;

    foreach my $id (sort { $players->{$a}->{last_name} cmp $players->{$b}->{last_name} || $players->{$a}->{first_name} cmp $players->{$b}->{first_name} } keys %{$players})
    {
        my $player = $players->{$id};
        my $arr = [];
        my $dob = "$3-$2-$1" if $player->{dob} =~ /^(\d{4})-(\d\d)-(\d\d)$/;
        push @{$arr}, $player->{id};
        push @{$arr}, substr($player->{first_name}, 0, 50);
        push @{$arr}, substr($player->{last_name}, 0, 50);
        push @{$arr}, $ratings->{$id} || 0;
        push @{$arr}, $player->{gender} || '';
        push @{$arr}, substr($player->{club}, 0, 25);
        push @{$arr}, $dob || '';
        $dbf->appendrow_arrayref($arr);
    }

    $dbf->closeDB;
    $file;
}

sub export_sm
{
    my $file = sprintf('%s/swiss_manager.txt', $opt{f});
    open(FILE, '>:encoding(UTF-8)', $file) || die "can't write to file $file\n";
    
    # What month/year is it?
    my $mmyy = "\u$mon$year";

    # Write the header.
    my $header = "ID number Name                              TitlFed  $mmyy GamesBorn  Flag\n";
    print FILE $header;

    # Prepare the format.
    # 00000000011111111112222222222333333333344444444445555555555666666666677777
    # 12345678901234567890123456789012345678901234567890123456789012345678901234
    # ID number Name                              TitlFed  Sep11 GamesBorn  Flag
    # 12508608  Abbaszadeh, Esmaeil                   IRI  1925    0
    #  7900139  Abbou, Meriem                     wf  ALG  2005    0        wi
    #  2500388  Connolly, Suzanne                     IRL  2012    0  1963  wi
    #  2500035  Orr, Mark J L                     m   IRL  2260    0  1955
    my $fmt = "%-8s  %-32s  %-2s  %3s  %-4s  %3d  %-4s  %s\n";

    # Export the data to this file.
    foreach my $id (sort { $players->{$a}->{last_name} cmp $players->{$b}->{last_name} || $players->{$a}->{first_name} cmp $players->{$b}->{first_name} } keys %{$players})
    {
        # Get the player.
        my $player = $players->{$id};

        # Prepare for the data for this record.
        my @data;

        # Swiss manager doesn't like IDs of less than 4 digits, so pad them.
        my $_id = $id < 1000 ? sprintf('%04s', $id) : $id;
        push @data, $_id;

        # Name.
        push @data, sprintf('%s, %s', $player->{last_name}, $player->{first_name});

        # Title.
        my $title = $player->{title};
        my $woman = 1 if $title =~ s/^W//;
        {
            $title = '',   last unless $title;
            $title = 'g',  last if $title eq 'GM';
            $title = 'i',  last if $title eq 'IM';
            $title = 'f',  last if $title eq 'FM';
            $title = 'c',  last if $title eq 'CM';
            $title = '';
        }
        $title = "w$title" if $woman;
        push @data, $title;

        # Federation.
        push @data, $player->{fed} || '';

        # Rating.
        push @data, $ratings->{$id} || '';

        # Games.
        push @data, 0;

        # YOB.
        my $year = '';
        $year = $1 if $player->{dob} =~ /^(\d{4})-(\d{2})-(\d{2})$/;
        push @data, $year;

        # Add gender (if female) and club (if there is one) but replace any occurrences of "w" in club.
        my $flag = '';
        $flag = 'w' if $player->{gender} eq 'F';
        my $club = $player->{club};
        if ($club)
        {
            $club =~ s/W/U/g;
            $club =~ s/w/u/g;
            $flag = $flag eq 'w' ? "$club $flag" : $club;
        }
        push @data, $flag;

        # Append it to the file.
        printf FILE $fmt, @data;
    }
    close FILE;

    $file;
}

sub archive
{
    my $file = sprintf('%s/%s%s.zip', $opt{f}, $mon, $year);
    
    my $zip = Archive::Zip->new;
    $zip->addFile($sp_file, &_nodir($sp_file));
    $zip->addFile($sm_file, &_nodir($sm_file));
    die "couldn't write ZIP archive $file" unless $zip->writeToFileNamed($file) == 0;

    $file;
}

sub _nodir
{
    my ($path) = @_;
    my ($file) = $path =~ /([^\/]+)$/;
    $file;
}
