package Parse::AFP;
$Parse::AFP::VERSION = '0.15';

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

sub make_next_member {
    my $self = shift;
    my $class = ref($self);
    my $struct = $self->{struct};
    my $field = $Parse::Binary::MemberFields{$class}[0];

    my $items = $struct->{$field};
    my $code = $self->SUPER::make_next_member;
    my $count = 0;

    sub {
        delete $items->[$count++] if $count;
        push @$items, &{$self->{_read_chunk}};
        goto &$code;
    };
}

sub read_file {
    my ($self, $file) = @_;
    return $self->SUPER::read_file($file) unless ref $self and $self->{lazy};

    open my $fh, '<', $file or die "Cannot open $file for reading: $!";
    binmode($fh);

    my ($code, $length, $data);
    read($fh, $code, 1);
    read($fh, $length, 2);
    read($fh, $data, (unpack('n', $length) - 2));

    if (!eof($fh)) {
        $self->{_read_chunk} = sub {
            my (@data, $type, $pos, $buf);

            read($fh, $code, 1);
            read($fh, $length, 2);

            # We now cheat and skip unintereting types.
            read($fh, $type, 3);

            our %IgnoreType;
            if (exists $IgnoreType{$type} and my $ofh = $self->{output}) {
                # We now ignore everything...
                read($fh, $buf, (unpack('n', $length) - 5));

                print $ofh $code, $length, $type, $buf;
                $self->{_read_chunk} = sub { () } if eof($fh);
                goto &{$self->{_read_chunk}};
            }

            $data[0] = unpack('H2', $code);
            seek($fh, -3, 1);
            read($fh, $data[1], (unpack('n', $length) - 2));
            $self->{_read_chunk} = sub { () } if eof($fh);

            return \@data;
        };
    }

    return $code.$length.$data;
}

sub callback_members {
    my $self = shift;
    $self->{callback_members} = { map { ($_ => 1) } @{$_[0]} };

    our %IgnoreType;
    local %IgnoreType;

    if ($self->{callback_members}{'*'} and $self->{output}) {
        my %table = reverse Parse::AFP::Record::DISPATCH_TABLE();
        %IgnoreType = 
            map { (pack('H6', $table{$_}) => 1) }
            grep { !$self->{callback_members}{$_} }
            keys %table;
    }

    while (my $member = $self->next_member) {
	$member->callback(scalar caller, @_);
    }
}

1;

__END__

=head1 NAME

Parse::AFP - IBM Advanced Function Printing Parser

=head1 VERSION

This document describes version 0.15 of Parse::AFP, released
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
