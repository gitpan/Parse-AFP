#!/usr/local/bin/perl
# $File: /local/member/autrijus/Parse-AFP//script/afpconv.pl $ $Author: autrijus $
# $Revision: #6 $ $Change: 3946 $ $DateTime: 2004-02-17T19:42:57.384625Z $

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";

$SIG{__WARN__} = sub { use Carp; Carp::cluck(@_) };
$SIG{__DIE__} = sub { use Carp; Carp::confess(@_) };

use strict;
use IO::File;
use Encode;
use Parse::AFP;
use Getopt::Std;

use vars qw/$opt_i $opt_o/;
getopts('i:o:'); $opt_i ||= shift;
die "Usage: $0 -i afpfile -o OutputFile\n" if (!$opt_i or !$opt_o);

my (%FontToId, %IdToFont);

##########################################################################

my $afp = Parse::AFP->new($opt_i, {lazy => 1});
$afp->set_output_file($opt_o);
$afp->callback_members(['MCF1', 'MCF', 'PTX', '*']);

##########################################################################

sub __ {
    $_[0]->write; $_[0]->remove;
}

sub MCF1 {
    my $rec = shift;
    my $font_e = substr($rec->CodedFontName, 2, 4);
    my $font_eid = $rec->CodedFontLocalId;
    $FontToId{$font_e} = $font_eid;
    $IdToFont{$font_eid} = $font_e;
    $rec->write; $rec->remove;
}

sub MCF {
    my $rec = shift;
    $rec->callback_members(['MCF::DataGroup']);
    $rec->write; $rec->remove;
}

sub MCF_DataGroup {
    my $data_group = shift;

    my $fqn = $data_group->first_member('FQN');
    my $rli = $data_group->first_member('RLI');
    my $font_e  = substr($fqn->Data, 2, 4);
    my $font_eid = $rli->Data;
    $FontToId{$font_e} = $font_eid;
    $IdToFont{$font_eid} = $font_e;
}

sub PTX {
    my $rec = shift;
    my $font_eid;
    $rec->callback_members(['PTX::SCFL', 'PTX::TRN'], \$font_eid);
    $rec->refresh;
    $rec->write; $rec->remove;
}

sub PTX_SCFL {
    my ($dat, $font_ref) = @_;
    $$font_ref = $dat->Data;
}

sub PTX_TRN {
    my ($dat, $font_ref) = @_;

    my $font_eid = $$font_ref or return;
    $IdToFont{$font_eid} =~ /^GT/ or next;
    my $font_cid = ($font_eid + 1);

    my $string = $dat->Data;
    while ($string =~ /(([\x00-\x7f]+)|((?:[\x80-\xff].)+))/g) {
	$dat->prepend_obj(
	    Class => 'PTX::SCFL',
	    Data  => ($2 ? $font_eid : $font_cid),
	);
	$dat->prepend_obj(
	    Class => 'PTX::TRN',
	    Data  => $1,
	);
    }
    $dat->remove;
}

1;
