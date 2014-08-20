#!/usr/local/bin/perl
use strict;
use Getopt::Std;

# Regex for one player specified on the command line (with the -p flag).
my $prgx = "[1-9]\\d*,[A-Z][-A-Za-z' ]+,[A-Z][-A-Za-z' .]+";

# Hash from country names to 3-letter codes.
my %cnt_fed; &get_cnt_fed();

# Options.
my %opt;
my $opt = 'hp:w:e:';
getopts($opt, \%opt);
sub help
{
    print <<EOH;
pgn2csv.pl [$opt]
convert a PGN file into an ICU-CSV rating report
  -p players in report
  -e event (optional)
  -w website (required)
examples:
  > $0 -p "7085,Baburin,Alexander:4017,Heidenfeld,Mark" olm_men_2014.pgn
EOH
    exit 0;
}

# Print help and exit.
&help() if $opt{h};

#
# Main program.
#

# Parse the players.
my %players;
my %names;
&parse_players;

# Read the file.
my @lines;
&read_file;

# Parse the file.
my %events;
my $start;
my $end;
my $rounds;
my %results;
my $lineno;
&parse_lines;

# Output CSV.
&output_csv();

#
# Helpers.
#

sub parse_players
{
    die "please use -p to specify players to appear in report\n" unless $opt{p};
    my @players = split /:/, $opt{p};
    foreach my $player (@players)
    {
        die "invalid player format ($player)\n" unless $player =~ /^([1-9]\d*),([A-Z][-A-Za-z' ]+),([A-Z][-A-Za-z' .]+)$/;
        my ($id, $last, $first) = ($1, $2, $3);
        $players{$id} = "$last,$first";
        $names{"$last,$first"} = $id;
    }
}

sub read_file
{
    my $file = shift @ARGV;
    die "no input PGN file specified" unless $file;
    die "can't read file $file" unless open FILE, $file;
    @lines = <FILE>;
    close FILE;
}

sub parse_lines
{
    my $state = 0;
    my %tags;

    foreach my $line (@lines)
    {
        $lineno++;
        my ($tag, $val);
        if ($line =~ /^\[(\w+)\s+"([^"]+)"\s*]\s*$/)
        {
            $tag = $1;
            $val = &trim($2);
            if ($tag =~ /^(White|Black)$/)
            {
                if ($val =~ /,/)
                {
                    $val =~ s/\s*,\s*/,/;
                }
                else
                {
                    $val =~ s/ /,/;
                }
            }
            $tags{$tag} = $val;
        }

        if ($state == 0 && $tag)
        {
            $state = 1;
        }
        elsif ($state == 1 && !$tag)
        {
            $state = 0;
            analyse_tags(%tags);
            %tags = ();
        }
    }
}

sub analyse_tags
{
    my %tags = @_;

    $events{$tags{Event}}++ if $tags{Event};

    if ($tags{Date})
    {
        $start = $tags{Date} if !$start || $start gt $tags{Date};
        $end = $tags{Date} if !$end || $end lt $tags{Date};
    }

    my $round = $1 if $tags{Round} =~ /^([1-9]\d*)/;
    die "no round information ($lineno)\n" unless $round;
    $rounds = $round if !$round || $round > $rounds;

    my $white = $tags{White};
    my $black = $tags{Black};
    my $welo = $tags{WhiteElo};
    my $belo = $tags{BlackElo};
    my $wtit = $tags{WhiteTitle};
    my $btit = $tags{BlackTitle};
    my $wfed = &get_fed($tags{WhiteFederation}, $tags{WhiteTeam});
    my $bfed = &get_fed($tags{BlackFederation}, $tags{BlackTeam});
    my $result = $tags{Result};
    die "no result information ($lineno)\n" unless $result =~ /^(1-0|0-1|1\/2-1\/2)$/;

    my $wid = $names{$white};
    my $bid = $names{$black};

    if ($wid)
    {
        my $wresult = $result eq '1-0' ? 1 : ($result eq '0-1' ? 0 : '=');
        $results{$wid}->{$round} = [$wresult, 'W', $black, $belo, $btit, $bfed];
    }

    if ($bid)
    {
        my $bresult = $result eq '1-0' ? 0 : ($result eq '0-1' ? 1 : '=');
        $results{$bid}->{$round} = [$bresult, 'B', $white, $welo, $wtit, $wfed];
    }
}

sub output_csv
{
    # Event.
    die "no event information" unless $opt{e} || %events;
    my $event = $opt{e};
    unless ($event)
    {
        my @events = sort { $events{$a} <=> $events{$b} } keys %events;
        $event = $events[-1];
    }
    $event = sprintf('"%s"', $event) if $event =~ /,/;
    print "Event,$event\n";

    # Start.
    die "no start information" unless $start;
    $start =~ s/\./-/g;
    print "Start,$start\n";

    # Finish.
    die "no end information" unless $end;
    $end =~ s/\./-/g;
    print "End,$end\n";

    # Rounds.
    die "no rounds information" unless $rounds;
    print "Rounds,$rounds\n";

    # Website.
    die "no website information (please supply with -w flag)" unless $opt{w};
    print "Website,$opt{w}\n\n";

    # Players.
    foreach my $id (sort { $a <=> $b } keys %players)
    {
        my $results = $results{$id};
        die sprintf("no results for player %d (%s)\n", $id, $players{$id}) unless $results;

        my $total = 0;

        printf "Player,%d,%s\n", $id, $players{$id};

        for (my $r=1; $r<=$rounds; $r++)
        {
            if ($results->{$r})
            {
                if ($results->{$r}->[3])
                {
                    printf "%d,%s\n", $r, join(',', @{$results->{$r}});
                }
                else
                {
                    printf "%d,%s,-\n", $r, $results->{$r}->[0];
                }
                $total+= 2 if $results->{$r}->[0] eq '1';
                $total+= 1 if $results->{$r}->[0] eq '=';
            }
            else
            {
                printf "%d,0,-\n", $r;
            }
        }

        printf "Total,%s\n\n", $total % 2 == 0 ? $total/2 : sprintf('%.1f', $total/2.0);
    }
}

sub trim
{
    my ($str) = @_;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    $str =~ s/\s+/ /g;
    $str;
}

sub get_fed
{
    foreach my $str (@_)
    {
        return $str if $str =~ /^[A-Z]{3}$/;
        return $cnt_fed{$str} if $cnt_fed{$str};
    }
    return "";
}

sub get_cnt_fed
{
    foreach my $line (<DATA>)
    {
        next unless $line =~ /^([A-Z]{3}) ([A-Z].+)/;
        $cnt_fed{$2} = $1;
    }
}

__DATA__
AFG Afghanistan
ALB Albania
ALG Algeria
AND Andorra
ANG Angola
ANT Antigua
ARG Argentina
ARM Armenia
ARU Aruba
AUS Australia
AUT Austria
AZE Azerbaijan
BAH Bahamas
BRN Bahrain
BAN Bangladesh
BAR Barbados
BLR Belarus
BEL Belgium
BIZ Belize
BEN Benin Republic
BER Bermuda
BHU Bhutan
BOL Bolivia
BIH Bosnia and Herzegovina
BOT Botswana
BRA Brazil
IVB British Virgin Islands
BRU Brunei Darussalam
BUL Bulgaria
BDI Burundi
CAM Cambodia
CMR Cameroon
CAN Canada
CHA Chad
CHI Chile
CHN China
TPE Chinese Taipei
COL Colombia
CGO Congo-Kinshasa
CRC Costa Rica
CRO Croatia
CUB Cuba
CYP Cyprus
CZE Czech Republic
DEN Denmark
DJI Djibouti
DOM Dominican Republic
ECU Ecuador
EGY Egypt
ESA El Salvador
ENG England
EST Estonia
ETH Ethiopia
FAI Faroe Islands
FIJ Fiji
FIN Finland
FRA France
GAB Gabon
GAM Gambia
GEO Georgia
GER Germany
GHA Ghana
GRE Greece
GUM Guam
GUA Guatemala
GCI Guernsey
GUY Guyana
HAI Haiti
HON Honduras
HKG Hong Kong
HUN Hungary
ISL Iceland
IND India
INA Indonesia
IRI Iran
IRQ Iraq
IRL Ireland
ISR Israel
ITA Italy
CIV Ivory Coast
JAM Jamaica
JPN Japan
JCI Jersey
JOR Jordan
KAZ Kazakhstan
KEN Kenya
KUW Kuwait
KGZ Kyrgyzstan
LAO Laos
LAT Latvia
LIB Lebanon
LES Lesotho
LBA Libya
LIE Liechtenstein
LTU Lithuania
LUX Luxembourg
MAC Macau
MKD Macedonia
MAD Madagascar
MAW Malawi
MAS Malaysia
MDV Maldives
MLI Mali
MLT Malta
MTN Mauritania
MRI Mauritius
MEX Mexico
MDA Moldova
MNC Monaco
MGL Mongolia
MNE Montenegro
MAR Morocco
MOZ Mozambique
MYA Myanmar
NAM Namibia
NEP Nepal
NED Netherlands
AHO Netherlands Antilles
NZL New Zealand
NCA Nicaragua
NGR Nigeria
NOR Norway
PAK Pakistan
PLW Palau
PLE Palestine
PAN Panama
PNG Papua New Guinea
PAR Paraguay
PER Peru
PHI Philippines
POL Poland
POR Portugal
PUR Puerto Rico
QAT Qatar
ROU Romania
RUS Russia
RWA Rwanda
SMR San Marino
STP Sao Tome and Principe
KSA Saudi Arabia
SCO Scotland
SEN Senegal
SRB Serbia
SEY Seychelles
SLE Sierra Leone
SIN Singapore
SVK Slovakia
SLO Slovenia
SOL Solomon Islands
SOM Somalia
RSA South Africa
KOR South Korea
ESP Spain
SRI Sri Lanka
SUD Sudan
SUR Surinam
SWZ Swaziland
SWE Sweden
SUI Switzerland
SYR Syria
TJK Tajikistan
TAN Tanzania
THA Thailand
TOG Togo
TRI Trinidad and Tobago
TUN Tunisia
TUR Turkey
TKM Turkmenistan
ISV US Virgin Islands
UGA Uganda
UKR Ukraine
UAE United Arab Emirates
USA United States of America
URU Uruguay
UZB Uzbekistan
VEN Venezuela
VIE Vietnam
WLS Wales
YEM Yemen
ZAM Zambia
ZIM Zimbabwe
