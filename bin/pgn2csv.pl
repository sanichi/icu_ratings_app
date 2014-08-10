#!/usr/local/bin/perl
use strict;
use Getopt::Std;

# Regex for one player specified on the command line (with the -p flag).
my $prgx = "[1-9]\\d*,[A-Z][-A-Za-z' ]+,[A-Z][-A-Za-z' .]+";

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
    my $wfed = $tags{WhiteFederation};
    my $bfed = $tags{BlackFederation};
    my $result = $tags{Result};
    die "no result information ($lineno)\n" unless $result =~ /^(1-0|0-1|1\/2-1\/2)$/;

    my $wid = $names{$white};
    my $bid = $names{$black};

    if ($wid)
    {
        my $wresult = $result eq '1-0' ? 1 : ($result eq '0-1' ? 0 : '=');
        $results{$wid}->{$round} = [$wresult, $black, $belo, $btit, $bfed];
    }

    if ($bid)
    {
        my $bresult = $result eq '1-0' ? 0 : ($result eq '0-1' ? 1 : '=');
        $results{$bid}->{$round} = [$bresult, $white, $welo, $wtit, $wfed];
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
                if ($results->{$r}->[2])
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
