#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";

use encoding 'utf8';
use File::Basename;
use Parse::AFP;

my %desc;
foreach my $type qw( Record Triplet PTX/ControlSequence ) {
    require "Parse/AFP/$type.pm";
    open my $fh, $INC{"Parse/AFP/$type.pm"} or die $!;
    while (<$fh>) {
	/'([A-Z][:\w]+)',\s+#\s?(.+)/ or next;
	$desc{$1} = $2;
    }
}

sub Header ();
sub Parse::AFP::PTX::TRN::ENCODING () { 'big5' };

die "Usage: $0 file.afp > file.html\n" unless @ARGV;

$SIG{__WARN__} = sub { use Carp; Carp::cluck(@_) };
$SIG{__DIE__} = sub { use Carp; Carp::confess(@_) };

my $input = shift;
my $afp = Parse::AFP->new($input, { lazy => 1 });
$input = basename($input);

print Header();
print "<h1>$input</h1><ol class='top'>\n";
dump_members($afp);
print "</ol></body></html>\n";

sub dump_afp {
    my $obj = shift;
    my $struct = $obj->struct;
    print "<table border=0 summary='$obj'>";

    my @keys = sort grep !/^_|^(?:Data|EscapeSequence|ControlCode|Length|CC|(?:Sub)?Type|FlagByte)$/, keys %$struct;
    push @keys, 'Data' if exists $struct->{Data};
    foreach my $key (@keys) {
	next if ref $struct->{$key};
	length($x = $struct->{$key}) or next;

	if ($obj->ENCODING and $key eq 'Data') {
	    $x = $obj->Data;
	    $x = qq("$x");
	}
	elsif ($x =~ /[^\w\s]/) {
	    $x = '<span class="hex">'.uc(join(' ',
		(length($x) <= 80) 
		    ? unpack('(H2)*', $x)
		    : (unpack('(H2)*', substr($x, 0, 80)), '...')
	    )).'</span>';
	}
	if ($key eq 'Data') {
	    print "<tr><td colspan='2' class='item'>$x</td></tr>\n";
	}
	else {
	    print "<tr><td class='label'>$key</td><td class='item'>$x</td></tr>\n";
	}
    }

    print "</table>";
    if ($obj->has_members) {
	print "<ol>";
	dump_members($obj);
	print "</ol>";
    }
}

sub dump_members {
    my $obj = shift;
    while (my $rec = $obj->next_member) {
	my $type = substr(ref($rec), 12);
	print "<li><div><strong>$type</strong>";
	print " &ndash; $desc{$type}" if exists $desc{$type};
	print "</div>";
	dump_afp($rec);
	print "</li>";
    }
}

use constant Header => << '.';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html><head><meta http-equiv='Content-Type' content='text/html; charset=UTF-8'><style type='text/css'><!--
body { background: #e0e0e0; font-family: times new roman, times; margin-left: 20px }
h1 { font-family: times }
span.hex { font-family: andale mono, courier }
ol { border-left: 1px dotted black }
ol.top { border-left: none }
table { font-size: small; border-left: 1px dotted black; padding-left: 6pt; width: 100% }
td.label { background: #d0d0d0; font-family: arial unicode ms, helvetica }
td.item { background: white; width: 100%; font-family: arial unicode ms, helvetica }
div { text-decoration: underline; background: #e0e0ff; font-family: arial unicode ms, helvetica }
--></style><title>AFP Dump</title></head><body>
.

1;
