# $File: /local/member/autrijus/Parse-AFP//t/1-basic.t $ $Author: autrijus $
# $Revision: #10 $ $Change: 3918 $ $DateTime: 2004-02-17T10:05:07.533350Z $

use strict;
use FindBin;
use lib "$FindBin::Bin/../inc";
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../Parse-Binary/lib";
use Test::More tests => 20;

$SIG{__WARN__} = sub { use Carp; Carp::cluck(@_) };
$SIG{__DIE__} = sub { use Carp; Carp::confess(@_) };

use_ok('Parse::AFP');

my $file = "$FindBin::Bin/in.afp";

ok(my $orig = Parse::AFP->read_file($file), 'read_file');
my $chunk1 = $1 if $orig =~ /^(Z.*?)Z/;

my $afp = Parse::AFP->new($file);
isa_ok($afp, 'Parse::AFP');
ok($afp->is_type('Base'), 'is_type("Base")');
is_deeply([$afp->fields], ['Record'], 'fields');
is($afp->field_format('Record'), 'H2 n/a* XX', 'field_format');

my $rec = $afp->first_member;

ok($rec->is_type('Record'), 'is_type("Record")');
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
is_deeply($new_scfl, $scfl, 'prepend_obj');
is($ptx->Length, $ptx_length + $new_scfl->Length, 'Length');
$scfl->remove;

$ptx->refresh;
is($ptx->Length, $ptx_length, 'remove');

1;
