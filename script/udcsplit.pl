#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";

use strict;
use Parse::AFP;
use Getopt::Std;
use File::Path 'rmtree';

my %NoUDC = (
    947 => qr{
        ^
            (?:
                [\x00-\x7f]+
            |
                (?:[\xA1-\xC5\xC9-\xF9].)+
            |
                (?:\xC6[^\xA1-\xFE])+
            )*
        $
    }x,
    835 => qr{^[^\x92-\xFE]*$}x,
);

my %opts;
getopts('i:o:c:', \%opts);
my $input       = $opts{i} || shift;
my $output      = $opts{o} || shift || 'udcdir';
my $codepage    = $opts{c} || 947;

die "Usage: $0 -c [947|835] -i input.afp -o udcdir\n"
    if grep !defined, $input, $codepage, $output;

rmtree([ $output ]) if -d $output;

my $NoUDC = $NoUDC{$codepage} or die "Unknown codepage: $codepage\n";

mkdir $output;
my $afp = Parse::AFP->new($input, { lazy => 1, output_file => "$output/0" });
$afp->callback_members([qw( BPG PTX * )]);

my ($has_udc, $name, $prev);

if ($has_udc) {
    rename("$output/$name" => "$output/$name.udc") or die $!;
}

sub BPG {
    $prev = $name; $name++;

    $afp->set_output_file("$output/$name");

    if ($has_udc) {
        print STDERR '.';
        rename("$output/$prev" => "$output/$prev.udc") or die $!;
        $has_udc = 0;
    }

    $_[0]->done;
}

sub PTX {
    my ($rec, $buf) = @_;

    # Now iterate over $$buf.
    my $pos = 2;
    my $len = length($$buf);

    while ($pos < $len) {
        my ($size, $code) = unpack("x${pos}CC", $$buf);
        $size or last;

        if ($code == 0xDA or $code == 0xDB) {
            if (substr($$buf, $pos + 2, $size - 2) !~ /$NoUDC/o) {
                $has_udc = 1;
                last;
            }
        }

        $pos += $size;
    }

    $rec->done;
}

sub __ { $_[0]->done }
