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

my %CodePages = (
    947 => {
        FillChar => "\xA1\x40",
        FirstChar => "\xA4\x40",
        CharPattern => qr{
            (
                [\x81-\xA0\xC7-\xC8\xFA-\xFE].      # UDC range 1
                |
                \xC6[\xA1-\xFE]                     # UDC range 2
            )
            |
            ([\x00-\x7f])                           # Single Byte
            |
            (..)                                    # Double Byte
        }x,
    },
    835 => {
        FillChar => "\x40\x40",
        FirstChar => "\x4C\x41",
        CharPattern => qr{
            ([\x92-\xFE].)                          # UDC
            |
            ((?!))                                  # Single Byte
            |
            ([\x41-\x91].)                          # Double Byte
        }x,
    },
);

my %opts;
getopts('i:o:f:c:d:u:', \%opts);

my $input       = $opts{i} || shift;
my $db          = $opts{f} || (-e 'fonts.db' ? 'fonts.db' : undef);
my $output      = $opts{o} || 'fixed.afp';
my $codepage    = $opts{c} || 947;
my $dbcs_pat    = $opts{d};
my $dir         = 'udcdir';

my @UDC;
die "Usage: $0 -c [947|835] -d dbcs_pattern -i input.afp -o output.afp -f fonts.db\n"
    if grep !defined, $input, $db, $output;

$CodePages{$codepage} or die "Unknown codepage: $codepage";

my ($FillChar, $FirstChar, $CharPattern, $NoUDC)
    = @{$CodePages{$codepage}}{qw( FillChar FirstChar CharPattern NoUDC )};

my (%FontToId, %IdToFont);

##########################################################################

no warnings qw(once numeric);
my $dbh = DBI->connect("dbi:SQLite:dbname=$db") or die $DBI::errstr;
my $fonts = $dbh->selectall_hashref("SELECT * FROM Fonts", 'FontName') or die $dbh->errstr;

print STDERR "Phase 1: Split...";

(system(
    $^X,
    "$FindBin::Bin/udcsplit.pl", 
    -i => $input,
    -o => $dir,
    -c => $codepage,
) == 0) or die $?;

opendir my $dh, $dir or die $!;

print STDERR "\nPhase 2: Join...";

unlink $output if -e $output;
open my $ofh, '>', $output or die $!;
binmode($ofh);

foreach my $file (sort { int($a) <=> int($b) } readdir($dh)) {
    my $name = $file;
    if ($file =~ /^(.+)\.udc$/) {
        $name = $1;
        udc4pca("$dir/$file" => "$dir/$name");
    }
    $name =~ /^\d+$/ or next;

    open my $ifh, '<', "$dir/$name" or die $!;
    binmode($ifh);
    local $/ = \32768;
    while (<$ifh>) {
        print $ofh $_;
    }
    close $ifh;
}

close $ofh;

print STDERR "\nDone!";

sub udc4pca {
    my ($in, $out) = @_;
    if (my $pid = fork) {
        waitpid($pid, 0);
        print STDERR ".";
    }
    else {
        my $afp = Parse::AFP->new($in, {lazy => 1, output_file => $out});
        $afp->callback_members([qw( MCF1 MCF PGD PTX EPG * )]);
        exit;
    }
}

sub __ {
    $_[0]->done;
}

my ($XUnit, $YUnit, $XPageSize, $YPageSize);
sub PGD {
    my $rec = shift;
    $XUnit = $rec->XLUnitsperUnitBase;
    $YUnit = $rec->YLUnitsperUnitBase;
    $XPageSize = $rec->XPageSize;
    $YPageSize = $rec->YPageSize;
    $rec->done;
}

sub MCF1 {
    my $rec = shift;
    my $font_e = substr($rec->CodedFontName, 2, 4);
    my $font_eid = $rec->CodedFontLocalId;
    $FontToId{$font_e} = $font_eid;
    $IdToFont{$font_eid} = $font_e;
    $rec->done;
}

sub MCF {
    my $rec = shift;
    $rec->callback_members(['MCF::DataGroup']);
    $rec->done;
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
    my ($rec, $buf) = @_;
    my $font_eid;

    # Now iterate over $$buf.
    my $pos = 11;
    my $len = length($$buf);

    while ($pos < $len) {
        my ($size, $code) = unpack("x${pos}CC", $$buf);
        $size or die "Incorrect parsing: $pos\n";

        if ($code == 0xDA or $code == 0xDB) {
            if (substr($$buf, $pos + 2, $size - 2) !~ $NoUDC) {
                $rec->callback_members([map "PTX::$_", qw(
                    SIM SBI STO SCFL AMI AMB BLN TRN
                )], \$font_eid);
                $rec->refresh;
                last;
            }
        }

        $pos += $size;
    }

    $rec->done;
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
    $font_name =~ s/^X\d/X0/;

    my $string = $dat->Data;
    my $data = '';

    # if $font_name is single byte...
    # simply add increments together without parsing UDC
    if ($dbcs_pat and $font_name !~ /$dbcs_pat/o) {
        $Increment{$font_name} ||= { @{
            $dbh->selectcol_arrayref(
            "SELECT Character, Increment FROM $font_name",
            { Columns=>[1, 2] }
        )} };
        $x += $Increment{$font_name}{$_}
            or die "Cannot find char ".unpack('(H2)*', $_)." in $font_name"
                foreach split(//, $string);
        return;
    }

    # my $dbcs_space_char = "\xFA\x40";

    while ($string =~ /$CharPattern/go) {
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
            $data .= $FillChar;
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
	    $x += $Increment{$font_name}{$3} || $Increment{$font_name}{$FirstChar};
	}
    }
    $dat->{struct}{Data} = $data;
}

sub EPG {
    my $rec = shift;

    if (!@UDC) {
	$rec->done;
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

    my %res = @{$dbh->selectcol_arrayref(
        "SELECT FontName, Resolution FROM Fonts", { Columns => [1,2] }
    )};
    my $name = $UDC[0]{FontName};
    $name =~ s/\s//g;
    my $res = $res{$name};

    $rec->spawn_obj(
	Class => 'IID',
	Color => '0008',
	ConstantData1 => '000009600960000000000000',
	ConstantData2 => '000000002D00',
	ConstantData3 => '00',
	XBase => '00',
	XCellSizeDefault => 0,
	XSize => 0,
	XUnits => $res,
	YBase => '00',
	YCellSizeDefault => 0,
	YSize => 0,
	YUnits => $res,
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
    $rec->done;
}

1;
