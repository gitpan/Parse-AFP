#!/usr/bin/perl

use strict;
use Encode;
use Parse::AFP;

die "Usage: $0 input.afp dir\n" unless @ARGV == 2;

my $input = shift;
my $output = shift;

mkdir $output;
my $afp = Parse::AFP->new($input, { lazy => 1 });
$afp->callback_members([qw( BR ER * )]);

sub Parse::AFP::BR::ENCODING () { 'cp500' };

sub BR {
    my $name = substr($_[0]->Data, 0, 8);
    print "Writing to $output/$name.afp\n";
    $afp->set_output_file("$output/$name.afp");
}

sub ER { return }

sub __ {
    $_[0]->write; $_[0]->remove;
}
