#!/usr/local/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";

use strict;
use DBI;
use DBD::SQLite;
use Data::Dumper;
use Parse::AFP;
use Getopt::Std;

getopts('i:o:f:');
my $input ||= shift;
my $db ||= 'fonts.db' if -e 'fonts.db';
my $output ||= 'fixed.afp';
my @UDC;

die "Usage: $0 -i input.afp -o output.afp -f fonts.db\n" if grep !defined, $input, $db, $output;

my (%FontToId, %IdToFont);

##########################################################################

my $dbh = DBI->connect("dbi:SQLite:dbname=$db") or die $DBI::errstr;
my $fonts = $dbh->selectall_hashref("SELECT * FROM Fonts", 'FontName') or die $dbh->errstr;

my $afp = Parse::AFP->new($input, {lazy => 1});
$afp->set_output_file($output);
$afp->callback_members([qw( MCF1 MCF PGD PTX EPG * )]);

sub __ {
    $_[0]->write; $_[0]->remove;
}

my ($XUnit, $YUnit, $XPageSize, $YPageSize);
sub PGD {
    my $rec = shift;
    $XUnit = $rec->XLUnitsperUnitBase;
    $YUnit = $rec->YLUnitsperUnitBase;
    $XPageSize = $rec->XPageSize;
    $YPageSize = $rec->YPageSize;
    $rec->write; $rec->remove;
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
    $data_group->callback_members(['Triplet::FQN', 'Triplet::RLI']);
}

{
my $font_e;

sub Triplet_FQN {
    my $fqn = shift;
    $font_e = $fqn->Data;
}

sub Triplet_RLI {
    my $rli = shift;
    my $font_eid = $rli->Data;
    $FontToId{$font_e} = $font_eid;
    $IdToFont{$font_eid} = $font_e;
}
}

sub PTX {
    my $rec = shift;
    my $font_eid;
    # print STDERR '.';
    $rec->callback_members([map "PTX::$_", qw(SIM SBI STO SCFL AMI AMB BLN TRN)], \$font_eid);
    $rec->refresh; 
    $rec->write; $rec->remove;
}

my ($x, $y);
sub PTX_AMI {
    my $rec = shift;
    $x = $rec->Data;
}

sub PTX_AMB {
    my $rec = shift;
    $y = $rec->Data;
}

my $InlineMargin;
sub PTX_SIM {
    my $rec = shift;
    $InlineMargin = $rec->Data;
}

my $BaselineIncrement;
sub PTX_SBI {
    my $rec = shift;
    $BaselineIncrement = $rec->Data;
}

sub PTX_BLN {
    my $rec = shift;
    $x = $InlineMargin;
    $y += $BaselineIncrement;
}

my ($XOrientation, $YOrientation);
sub PTX_STO {
    my $rec = shift;
    $XOrientation = $rec->Orientation;
    $YOrientation = $rec->WrapDirection;
}

sub PTX_SCFL {
    my ($dat, $font_ref) = @_;
    $$font_ref = $dat->Data;
}

my %Increment;
sub PTX_TRN {
    my ($dat, $font_ref) = @_;

    my $font_eid = $$font_ref;
    my $font_name = $IdToFont{$font_eid};

    my $string = $dat->Data;
    my $data = '';

    # my $dbcs_space_char = "\xFA\x40";

    while ($string =~ /([\x81-\xA0\xC7-\xC8\xFA-\xFE].|\xC6[\xA1-\xFE])|([\x00-\x7f])|(..)/g) {
        # ... calculate position, add to fonts to write ...

        if ( $1 || $3 ) {
	    $Increment{$font_name} ||= { @{
		$dbh->selectcol_arrayref(
		"SELECT Character, Increment FROM $font_name",
		{ Columns => [1, 2] }
	    )} };
	}

	if (defined $1) {
            push @UDC, {
                X => $x,
                Y => $y,
                Character => $1,
                FontName => $font_name
            };
            $data .= "\xA1\x40";
	    $x += $Increment{$font_name}{$1};
	}
	elsif (defined $2) {
	    # single byte
	    $Increment{$font_name} ||= { @{
		$dbh->selectcol_arrayref(
		"SELECT Character, Increment FROM $font_name",
		{ Columns=>[1, 2] }
	    )} };
	    $x += $Increment{$font_name}{$2}
	      or die "Cannot find char ".unpack('(H2)*', $2)." in $font_name";
	    $data .= $2;
  	    #print $font_name, "=", $x, "\n";
	}
	else {
	    $data .= $3;
	    $x += $Increment{$font_name}{$3};
	}
    }
    $dat->{struct}{Data} = $data;
}

sub EPG {
    my $rec = shift;

    if (!@UDC) {
	$rec->write; $rec->remove;
	return;
    }

    # ... write out the actual BII..IOC..IID..ICP..IRD..EII images ...
    #print "Writing out Bitmap...\n" if @UDC;

    # Construct: 
    $rec->spawn_obj(
	Class => 'BII',
	Data  => 'UDCImage',
    )->write;

    $rec->spawn_obj(
	Class => 'IOC',
	ConstantData1 => ("00" x 8),
	ConstantData2 => ("FF" x 2),
	Reserved1 => '00',
	Reserved2 => '00',
	XMap => '03e8',
	XOffset => 0,
	XOrientation => $XOrientation,
	YMap => '03e8',
	YOffset => 0,
	YOrientation => $YOrientation,
    )->write;
    $rec->spawn_obj(
	Class => 'IID',
	Color => '0008',
	ConstantData1 => '000009600960000000000000',
	ConstantData2 => '000000002D00',
	ConstantData3 => '00',
	XBase => '00',
	XCellSizeDefault => 0,
	XSize => 0,
	XUnits => 3000, # XXX - get from Fonts
	YBase => '00',
	YCellSizeDefault => 0,
	YSize => 0,
	YUnits => 3000,
    )->write;

    foreach my $char (@UDC) {
	my $sth = $dbh->prepare("SELECT * FROM $char->{FontName} WHERE Character = ?");
	$sth->execute($char->{Character});

	my $row = $sth->fetchrow_hashref or next;

	my ($X, $Y) = @{$char}{qw( X Y )};
	$X += $row->{ASpace};
	$Y -= $row->{BaseOffset};

	if ($YOrientation eq '5a00') {
	    ($X, $Y) = ($XPageSize - $Y, $X);
	}

	$rec->spawn_obj(
	    Class => 'ICP',
	    XCellOffset => $X,
	    XCellSize => $row->{Width},
	    XFillSize => $row->{Width},
	    YCellOffset => $Y,
	    YCellSize => $row->{Height},
	    YFillSize => $row->{Height},
	)->write;
	$rec->spawn_obj(
	    Class => 'IRD',
	    ImageData => $row->{Bitmap},
	)->write;
    }

    $rec->spawn_obj(
	Class => 'EII',
	Data  => 'UDCImage',
    )->write;

    @UDC = ();
    $rec->write; $rec->remove;
}

1;

__END__


