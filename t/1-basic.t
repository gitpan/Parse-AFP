# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More tests => 20;

use_ok('Parse::AFP');
use_ok('File::Slurp');

ok(my $orig = read_file("$FindBin::Bin/in.afp"), 'read in.afp');
my $chunk1 = $1 if $orig =~ /^(Z.*?)Z/;

my $afp = Parse::AFP->new("$FindBin::Bin/in.afp");

isa_ok($afp, 'Parse::AFP');
ok($afp->is_type('Base'), 'is_type("Base")');
is_deeply([$afp->fields], ['MemberData'], 'fields');
is($afp->field_format('MemberData'), 'C n/a* XX', 'field_format');

my $rec = ($afp->members)[0];

is($rec->dump, $chunk1, 'dump' );
is($afp->dump, $orig, 'roundtrip');
$afp->refresh;
is($afp->dump, $orig, 'roundtrip after refresh');

my ($member) = $afp->members;
isa_ok($member, 'Parse::AFP::Base'); 
my ($fqn) = $afp->members_recursive('FQN');
isa_ok($fqn, 'Parse::AFP::Triplet::FQN'); 
is($fqn->Data, 'X1GT12  ', 'Got correct font name');

my ($scfl) = $afp->members_recursive('SCFL');
is($scfl->Length, length($scfl->dump), 'Length should equal to length(dump)');

my $ptx = $scfl->parent;
my $ptx_length = $ptx->Length;
$ptx->refresh;
is($ptx->Length, $ptx_length, 'refresh should not affect Length');

my $last_cc = ($ptx->members)[-1]->ControlCode;
my $new_scfl = $scfl->prepend_obj(
    Class => 'PTX::SCFL',
    Data  => 1,
);
isa_ok($new_scfl, 'Parse::AFP::PTX::SCFL');

$ptx->refresh;
is(($ptx->members)[-1]->ControlCode, $last_cc, 'PTX->refresh');
is_deeply($scfl, $new_scfl, 'prepend_obj');
is($ptx->Length, $ptx_length + $new_scfl->Length, 'Length');
$scfl->remove;

$ptx->refresh;
is($ptx->Length, $ptx_length, 'remove');

1;
