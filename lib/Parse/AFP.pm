# $File: /local/member/autrijus/Parse-AFP//lib/Parse/AFP.pm $ $Author: autrijus $
# $Revision: #12 $ $Change: 3946 $ $DateTime: 2004-02-17T19:42:57.384625Z $

package Parse::AFP;
$Parse::AFP::VERSION = '0.04';

use strict;
use base 'Parse::AFP::Base';
use constant FORMAT => (
    Record => ['H2 n/a* XX', '*', '2'],
);
use constant BASE_CLASS => __PACKAGE__;

# Must start with the magic byte 0x90
sub valid_memberdata { $_[-1][0] eq '5a' }

1;

__END__

=head1 NAME

Parse::AFP - IBM Advanced Function Printing Parser

=head1 VERSION

This document describes version 0.04 of Parse::AFP, released February 18, 2004.

=head1 SYNOPSIS

    use Parse::AFP;
    my $afp = Parse::AFP->new('input.afp');
    while (my $rec = $afp->members) {
	print $rec->dump;
	# ...
	$rec->refresh; # if modified
    }
    $afp->refresh; # if modified
    $afp->write('output.afp');

=head1 DESCRIPTION

This module processes IBM's B<AFP> (Advanced Function Printing) files
into an object hierarchy; each object may be individually modified, dumped
into binary, or written back to another AFP file.

=head1 METHODS

Methods below applies to all objects in the objects hierarchy.

=head2 new

Constructor.  Takes either a filename, or a scalar reference to content.

=head2 dump

Returns the binary representation of the current object.

=head2 write

Takes a filename and writes the binary representation to it.

=head2 refresh

Regenerate binary representation from in-memory data from the object
itself and its members.  Also refreshes all uplevel parents.

=head2 members

Returns a list of member objects, if any.

=head2 parent

Returns the parent of this object, or I<undef> if this is the toplevel object.

=head1 ACCESSORS

Each class may define additional accessors, in the form of C<FieldName>
and C<SetFieldName>.  There are no accessors for the toplevel B<Parse::AFP>
object.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
