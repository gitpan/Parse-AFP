#!/usr/bin/perl

use strict;
use Encode;
use File::Glob 'bsd_glob';
use File::Basename;
use DBI;
use DBD::SQLite;
use Parse::AFP;

use constant GCG_Elements => [
    qw( Increment Ascend Descend ASpace BSpace CSpace BaseOffset _FNMCount )
];
use constant FNI_Elements => [
    qw( Width Height _FNGOffset )
];
use constant +{ map { +GCG_Elements->[$_] => $_ } 0..$#{+GCG_Elements} };
use constant +{ map { +FNI_Elements->[$_] => $_ } 0..$#{+FNI_Elements} };

$|++;

die "Usage: $0 dir fonts.db\n" unless @ARGV == 2;

my $input = shift;
my $output = shift;
our ($dbh, $sth, $sth_rotated);
our $FontName;
our (%GCG, %FNI, @FNM, $FNG);
our ($FCSName, $CPName, $Section, $Rotation);
our ($MaxWidth, $MaxHeight, $Resolution);

unlink $output if $output;

$dbh = DBI->connect("dbi:SQLite:dbname=$output") or die $DBI::errstr;
init_db();

my @files = bsd_glob("$input/X0*.afp");
foreach my $file (sort @files) {
    basename($file) =~ /^(X0([^.]+))/ or next;

    $FontName = $1;
    init_table();

    my $name = $2;
    print "Parsing font $name.";
    Parse::AFP->new($file, { lazy => 1 })->callback_members([qw( CFC CFI )]);

    $dbh->do(
        "INSERT INTO Fonts VALUES (?, ?, ?, ?)", {},
        $FontName, $Resolution, 0, 0
    );
    print "\n";
}

$dbh->commit;
$dbh->disconnect;

exit;

my $CFIRepeatingGroupLength;
sub CFC {
    $CFIRepeatingGroupLength = $_[0]->CFIRepeatingGroupLength;
}

sub CFI {
    my $data = $_[0]->Data;
    my $offset = 0;
    while (my $CFIRepeatingGroup = substr($data, $offset, $CFIRepeatingGroupLength)) {
        ($FCSName, $CPName, $Section) = unpack("a8a8x8C", $CFIRepeatingGroup);

        %GCG = %FNI = @FNM = (); $FNG = ''; $Rotation = 0;

        die unless -e "$input/".Encode::decode( cp500 => $CPName ).".afp";
        die unless -e "$input/".Encode::decode( cp500 => $FCSName ).".afp";

        Parse::AFP->new(
            "$input/".Encode::decode( cp500 => $CPName ).".afp", { lazy => 1 }
        )->callback_members([qw( CPC CPI )]);

        Parse::AFP->new(
            "$input/".Encode::decode( cp500 => $FCSName ).".afp", { lazy => 1 }
        )->callback_members([qw( FNC FNI FNM FNG )]);

        write_record(); 

        $offset += $CFIRepeatingGroupLength; 
        print ".";
    }
}

sub write_record {
    while (my ($rotation, $fni) = each %FNI) {
        $sth = $dbh->prepare_cached(
            $rotation
                ? "INSERT INTO RotationInfo VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
                : "INSERT INTO $FontName VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        );
        foreach my $codepoint (keys %GCG) {
            my $gcg = $GCG{$codepoint};
            my $fnc = $fni->{$gcg} or next;

            defined(my $count = pop @$fnc) or next;
            my $fnm = $FNM[$count] or die "Cannot find fnm #$count";

            # printf "%s - 0x%02X 0x%02X - @$fnm\n", $rotation, $Section, $codepoint;

            if ($rotation) {
                $sth->execute(
                    ($Section ? pack('n', $Section * 256 + $codepoint) : pack('C', $codepoint)),
                    @$fnc,
                    $FontName,
                    $rotation,
                );
                next;
            }

            # default rotation
            $sth->execute(
                ($Section ? pack('n', $Section * 256 + $codepoint) : pack('C', $codepoint)),
                @$fnc,
                unpack(
                    'H*',
                    substr($FNG, pop @$fnm, int(($fnm->[Width] + 7)/8)*$fnm->[Height])
                ),
                @$fnm,
            );
        }
    }
}

my $CPIRepeatingGroupLength;
sub CPC {
    $CPIRepeatingGroupLength = $_[0]->CPIRepeatingGroupLength;
}

sub CPI {
    my $data = $_[0]->Data;
    my $offset = 0;
    while (my $CPIRepeatingGroup = substr($data, $offset, $CPIRepeatingGroupLength)) {
        our ($GCGID, $CodePoint) = unpack("a8xC", $CPIRepeatingGroup);
        #$GCGID = Encode::decode( cp500 => $GCGID ); # XXX
        $GCG{$CodePoint} = $GCGID;
        $offset += $CPIRepeatingGroupLength; 
    }
}

my $FNIRepeatingGroupLength;
my $FNMRepeatingGroupLength;
sub FNC {
    $FNIRepeatingGroupLength = $_[0]->FNIRepeatingGroupLength;
    $FNMRepeatingGroupLength = $_[0]->FNMRepeatingGroupLength;
    die "UnitXBase other than 00 not handled" unless $_[0]->UnitXBase eq '00';
    $Resolution = $_[0]->UnitXValue;
}

sub FNI {
    my $data = $_[0]->Data;
    my $offset = 0;

    while (my $FNIRepeatingGroup = substr($data, $offset, $FNIRepeatingGroupLength)) {
        my ($GCGID, $CharInc, $AscendHt, $DescendDp, $Reserved, $FNMCnt, $ASpace, $BSpace, $CSpace, $BaseOset) = unpack("a8nnnnnnnnx2n", $FNIRepeatingGroup);  
    
        for ($AscendHt, $DescendDp, $ASpace, $CSpace, $BaseOset) {
            # cast "unsigned short" to "signed short"
            $_ -= 65536 if $_ > 32768;
        }

        #      $GCGID = Encode::decode( cp500 => $GCGID ); # XXX

        $FNI{$Rotation}{$GCGID} = [
            $CharInc, $AscendHt, $DescendDp, $ASpace, $BSpace, $CSpace, $BaseOset, $FNMCnt
        ];

        $offset += $FNIRepeatingGroupLength;
    }

    $Rotation += 90;
}

sub FNM {
    my $data = $_[0]->Data;
    my $offset = 0;
 
    while (my $FNMRepeatingGroup = substr($data, $offset, $FNMRepeatingGroupLength)) {
        my ($w, $h, $o) = unpack("nnN", $FNMRepeatingGroup);
        push @FNM, [ $w+1, $h+1, $o ];
        $offset += $FNMRepeatingGroupLength;
    }
}

sub FNG { $FNG .= $_[0]->Data; }

sub init_db {
    $dbh->begin_work;
    $dbh->do('PRAGMA default_cache_size = 200000; ') or die $dbh->errstr;
    $dbh->do('PRAGMA default_synchronous = OFF; ') or die $dbh->errstr;

    $dbh->do(q(
CREATE TABLE Fonts (
    FontName        VARCHAR(255) PRIMARY KEY,
    Resolution      INTEGER,
    FixedWidth      INTEGER,
    FixedHeight     INTEGER
);
    ));

    $dbh->do(q(
CREATE TABLE RotationInfo (
    Character       VARCHAR(6),

    Increment       INTEGER,
    Ascend          INTEGER,
    Descend         INTEGER,
    ASpace          INTEGER,
    BSpace          INTEGER,
    CSpace          INTEGER,
    BaseOffset      INTEGER,

    FontName        VARCHAR(255),
    Rotation        INTEGER
);
    ));

    $dbh->do(q(
CREATE INDEX RotationInfo_1 ON RotationInfo(FontName, Character, Rotation);
    ));
}

sub init_table {
    $dbh->do(qq(
CREATE TABLE $FontName (
    Character       VARCHAR(6) PRIMARY KEY,

    Increment       INTEGER,
    Ascend          INTEGER,
    Descend         INTEGER,
    ASpace          INTEGER,
    BSpace          INTEGER,
    CSpace          INTEGER,
    BaseOffset      INTEGER,

    Bitmap          VARCHAR(255),

    Width           INTEGER,
    Height          INTEGER
);
    ));
}

