#!/usr/local/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";

use strict;
use DBI;
use DBD::SQLite;
use Data::Dumper;
use Parse::AFP;
use Getopt::Long;
use File::Glob 'bsd_glob';

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
        NoUDC => qr{^
            (?:
                [\x00-\x7f]+
            |
                (?:[\xA1-\xC5\xC9-\xF9].)+
            |
                (?:\xC6[^\xA1-\xFE])+
            )*
        $}x,
    },
    835 => {
        FillChar => "\x40\x40",
        FirstChar => "\x4C\x41",
        CharPattern => qr{
            ([\x92-\xFE].)                          # UDC
            |
            ((?!))                                  # Single Byte
            |
            ([\x40-\x91].)                          # Double Byte
        }x,
        NeedDBCSPattern => 1,
        NoUDC => qr{^[^\x92-\xFE]*$}x,
    },
);

my ($input, $dbcs_pattern, @db);
my $codepage    = 947;
my $output      = 'fixed.afp';
my $dir         = 'udcdir';
my $adjust;

GetOptions(
    'i|input:s'         => \$input,
    'f|fontdb:s@'       => \@db,
    'o|output:s'        => \$output,
    'u|udcdir:s'        => \$dir,
    'd|dbcs-pattern:s'  => \$dbcs_pattern,
    'c|codepage:i'      => \$codepage,
    'a|adjust'          => \$adjust,
);

$input ||= shift;
@db = sort grep /\.f?db$/i, map { (-d $_) ? bsd_glob("$_/*") : $_ } (@db ? @db : 'fonts.db');

die "Usage: $0 [-a] [-c 947|835] -d dbcs_pattern -i input.afp -o output.afp -f fonts.db\n"
    if !@db or grep !defined, $input, $output;

$CodePages{$codepage} or die "Unknown codepage: $codepage";

my ($FillChar, $FirstChar, $CharPattern, $NeedDBCSPattern, $NoUDC)
    = @{$CodePages{$codepage}}{qw( FillChar FirstChar CharPattern NeedDBCSPattern NoUDC )};

die "Need DBCS Pattern with -d for thsi codepage"
    if $NeedDBCSPattern and !$dbcs_pattern;

my (%FontToId, %IdToFont);

##########################################################################

no warnings qw(once numeric);

my %errors;
my $db = shift(@db);
die "No such database: $db" unless -e $db;
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=$db", '', '', {
        PrintError => 0,
        HandleError => sub { $errors{$_[0]}++ },
    }
) or die $DBI::errstr;
my $fonts = $dbh->selectall_hashref("SELECT * FROM Fonts", 'FontName') or die $dbh->errstr;

foreach my $idx (0..$#db) {
    my $filename = $dbh->quote($db[$idx]);
    $dbh->do("ATTACH DATABASE $filename AS DB$idx") or die $dbh->errstr;
    my $more_fonts = $dbh->selectall_hashref("SELECT * FROM Fonts", 'FontName') or die $dbh->errstr;
    %$fonts = (%$fonts, %$more_fonts);
}

print STDERR "Phase 1: Split...";

(system(
    $^X,
    "$FindBin::Bin/udcsplit.pl", 
    -i => $input,
    -o => $dir,
    -c => $codepage,
) == 0) or die $?;

opendir my $dh, $dir or die $!;
my @files = sort { int($a) <=> int($b) } grep /\d/, readdir($dh);
if (!grep /udc$/, @files) {
    print STDERR "\nPhase 2: Skipped, no UDC found...";

    if ($input ne $output) {
        require File::Copy;
        File::Copy::copy($input => $output);
    }

    print STDERR "\nDone!\n";
    exit;
}

print STDERR "\nPhase 2: Join...";

unlink $output if -e $output;
open my $ofh, '>', $output or die $!;
binmode($ofh);

foreach my $file (@files) {
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

dbmopen %errors, 'errors', 0644;
if (my @errors = sort keys %errors) {
    print "\nExceptions encountered:\n";
    print join "\n", @errors, '';
}
dbmclose %errors;
unlink glob("errors.*");

print STDERR "\nDone!\n";

sub udc4pca {
    my ($in, $out) = @_;
    if (my $pid = fork) {
        waitpid($pid, 0);
        print STDERR ".";
    }
    else {
        dbmopen %errors, 'errors', 0644;
        my $afp = Parse::AFP->new($in, {lazy => 1, output_file => $out});
        $afp->callback_members([qw( MCF1 MCF PGD PTX EMO EPG * )]);
        exit;
    }
}

##########################################################################

my @UDC;
sub __ {
    $_[0]->done;
}

my ($x, $y);
my ($XUnit, $YUnit, $XPageSize, $YPageSize);
sub PGD {
    my $rec = shift;
    $XUnit = $rec->XLUnitsperUnitBase;
    $YUnit = $rec->YLUnitsperUnitBase;
    $XPageSize = $rec->XPageSize;
    $YPageSize = $rec->YPageSize;
    $rec->done;
    $x = $y = 0;
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
                    SIM SBI STO SCFL AMI AMB RMI RMB BLN TRN
                )], \$font_eid);
                $rec->refresh;
                last;
            }
        }

        $pos += $size;
    }

    $rec->done;
}

sub PTX_AMI {
    my $rec = shift;
    $x = $rec->Data;
}

sub PTX_AMB {
    my $rec = shift;
    $y = $rec->Data;
}

sub PTX_RMI {
    my $rec = shift;
    $x += $rec->Data;
}

sub PTX_RMB {
    my $rec = shift;
    $y += $rec->Data;
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
    if ($dbcs_pattern and $font_name !~ /$dbcs_pattern/o) {
        $Increment{$font_name} ||= { @{
            $dbh->selectcol_arrayref(
            "SELECT Character, Increment FROM $font_name",
            { Columns=>[1, 2] }
        ) || [] } };
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
	    ) || [] } };
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
	    ) || [] } };
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

BEGIN { *EMO = *EPG; }

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
	my $sth = $dbh->prepare("SELECT * FROM $char->{FontName} WHERE Character = ?") or next;
	$sth->execute($char->{Character});

	my $row = $sth->fetchrow_hashref or next;

	my ($X, $Y) = @{$char}{qw( X Y )};
	$X += $row->{ASpace};

	my $oset = $row->{BaseOffset};
	$oset = int($oset * 3 / 4) if $adjust;
	$Y -= $oset;

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
