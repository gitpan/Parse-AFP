package Parse::AFP;
$Parse::AFP::VERSION = '0.16';

use strict;
use base 'Parse::AFP::Base';
use constant FORMAT => (
    Record => ['H2 n/a* XX', '*', '2'],
);
use constant BASE_CLASS => __PACKAGE__;

# Must start with the magic byte 0x90
sub valid_memberdata { $_[-1][0] eq '5a' }

sub valid_unformat {
    my ($self, $content, $data) = @_;
    return if $content->[0] ne '5a';
    my $members = $self->{callback_members};
    my $table = Parse::AFP::Record->dispatch_table;
    my $type = $table->{ unpack('H6', $content->[1]) } or return;
    if (!$members->{ $type } and my $fh = $self->output) {
	print $fh $$data;
	return;
    }
    return 1;
}

sub callback_members {
    my $self = shift;
    $self->{callback_members} = { map { ($_ => 1) } @{$_[0]} };

    if ($self->{callback_members}{'*'} and $self->{output} and $self->{input}) {
        return $self->tight_loop(@_);
    }

    while (my $member = $self->next_member) {
	$member->callback(scalar caller, @_);
    }
}

sub _noop { }

sub read_file {
    my ($self, $file) = @_;

    open my $fh, "< $file" or die "Cannot open $file for reading: $!";
    binmode($fh);

    if ($self->{lazy} and $self->{output_file}) {
        $self->{input} = $fh;
        $self->set_output_file($self->{output_file});
        return '';
    }

    local $/;
    return scalar <$fh>;
}

sub tight_loop {
    my $self = shift;
    my $callback = caller(1);
    my $ofh = $self->{output};
    my $is_dirty;
    my ($header, $buf);

    local *Parse::AFP::Record::write = \&_noop;
    local *Parse::AFP::Record::remove = \&_noop;
    local *Parse::AFP::PTX::refresh_parent = sub {
        my $self = shift;
        $self->refresh_length;
        print $ofh $self->dump;
        $is_dirty = 1;
    };

    my %xable = Parse::AFP::Record::DISPATCH_TABLE();
    my %table = reverse Parse::AFP::Record::DISPATCH_TABLE();
    my %IgnoreType = 
        map { (pack('H6', $table{$_}) => 1) }
        grep { !$self->{callback_members}{$_} }
        keys %table;

    my $fh = $self->{input};
    seek $fh, 0, 0;

    my $attr = { lazy => 1, output => $ofh };

    while (!eof($fh)) {
        read($fh, $header, 6);
        seek $fh, -6, 1;
        read($fh, $buf, (unpack('n', substr($header, 1, 2)) + 1));

        # We now cheat and skip unintereting types.
        if (exists $IgnoreType{substr($header, -3)}) {
            print $ofh $buf;
            next;
        }

        # Do Something Interesting with $header and $buf
        $is_dirty = 0;
        Parse::AFP::Record->new( \$buf, $attr )->callback($callback, @_);
        print $ofh $buf unless $is_dirty;
        next;
    }
}

1;

__END__

=head1 NAME

Parse::AFP - IBM Advanced Function Printing Parser

=head1 VERSION

This document describes version 0.16 of Parse::AFP, released
October 12, 2004.

=head1 SYNOPSIS

    use Parse::AFP;
    my $afp = Parse::AFP->new('input.afp');
    while (my $rec = $afp->next_member) {
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

Running the bundled C<afpdump.pl> on a AFP file will probably explain
this module's behaviour better than reading the documentation.

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

=head2 next_member

Iterator for member objects.

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
