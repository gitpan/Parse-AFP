#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";

use encoding 'utf8';
use File::Basename;
use Parse::AFP;

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
    foreach my $key (sort keys %$struct) {
	next if $key =~ /^_/ or ref $struct->{$key};
	length($x = $struct->{$key}) or next;

	if ($obj->ENCODING and $key eq 'Data') {
	    $x = $obj->Data;
	    $x = qq("$x");
	}
	elsif ($x =~ /[^\w\s]/) {
	    $x = '<span class="hex">'.uc(join(' ', unpack('(H2)*', $x))).'</span>';
	}
	print "<tr><td class='label'>$key</td><td class='item'>$x</td></tr>\n";
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
	print "<li><strong>". substr(ref($rec), 12)."</strong>";
	dump_afp($rec);
	print "</li>";
    }
}

use constant Header => << '.';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html><head><meta http-equiv='Content-Type' content='text/html; charset=UTF-8'><style type='text/css'><!--
body { background: #e0e0e0 }
h1 { text-decoration: underline }
span.hex { font-style: italic }
ol { border-left: 1px dotted black }
ol.top { border-left: none }
table { font-size: small; border-left: 1px dotted black; padding-left: 6pt }
td.label { background: #d0d0d0 }
td.item { background: white; width: 100% }
strong { text-decoration: underline; background: #c0c0ff; display: block }
--></style><title>AFP Dump</title></head><body>
.

1;
