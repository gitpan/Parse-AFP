# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::Base;

use 5.008002;
use bytes;
use strict;

use NEXT;
use File::Slurp;
use Parse::AFP::FixedFormat;

use constant FORMAT => ( Data => 'a*' );
use constant SUBFORMAT => ();
use constant PADDING => undef;
use constant BASE_CLASS => 'Parse::AFP';
use constant MEMBER_CLASS => undef;
use constant DISPATCH_FIELD => undef;
use constant DISPATCH_TABLE => ();
use constant ENCODING => undef;

sub classname {
    my ($self, $class) = @_;
    return undef unless $class;
    return join('::', $self->BASE_CLASS, $class);
}

sub member_class {
    my ($self) = @_;
    return $self->classname( $self->MEMBER_CLASS );
}

sub dispatch_class {
    my ($self, $field) = @_;
    return $self->classname( $self->dispatch_table->{$field} );
}

sub load_module {
    my ($class, $module) = @_;
    return unless defined $module;

    $module =~ s{::}{/}g;
    require "$module.pm";
}

sub init {
    my ($class) = @_;

    no strict 'refs';
    return if ${"$class\::init_done"};

    $class->load_module($class->member_class);

    my $hash = { $class->DISPATCH_TABLE };
    *{"$class\::dispatch_table"} = sub { $hash };

    my $dispatch_field = undef;
    if (defined(&{"$class\::DISPATCH_FIELD"})) {
	$dispatch_field = $class->DISPATCH_FIELD;
    }
    *{"$class\::dispatch_field"} = sub { $dispatch_field };

    my @format = $class->FORMAT;
    if (my @subformat = $class->SUBFORMAT) {
	my @new_format;
	while (my ($field, $format) = splice(@format, 0, 2)) {
	    if ($field eq 'Data') {
		push @new_format, @subformat;
	    }
	    else {
		push @new_format, ($field => $format);
	    }
	}
	@format = @new_format;
    }

    my (@fields, @formats, @pack_formats);
    my (%field_format, %field_pack_format);
    my (%field_parser, %field_packer, %field_length);
    while (my ($field, $format) = splice(@format, 0, 2)) {
	push @fields, $field;
	$format = [ $format ] unless ref $format;

	my $string = join(':', $field, @$format);
	$field_format{$field} = $format->[0];
	$field_length{$field} = length(pack($format->[0], 0));
	$field_parser{$field} = Parse::AFP::FixedFormat->new( [ $string ] );
	push @formats, $string;

	s/\s*X\s*//g for @$format;
	my $pack_string = join(':', $field, @$format);
	$field_pack_format{$field} = $format->[0];
	$field_packer{$field} = Parse::AFP::FixedFormat->new( [ $pack_string ] );
	push @pack_formats, $pack_string;
    }

    *{"$class\::fields"} = sub { @fields };
    *{"$class\::formats"} = sub { @formats };
    *{"$class\::pack_formats"} = sub { @pack_formats };
    *{"$class\::field_format"} = sub { $field_format{$_[1]} };
    *{"$class\::field_pack_format"} = sub { $field_pack_format{$_[1]} };
    *{"$class\::field_length"} = sub { $field_length{$_[1]} };

    my $parser = Parse::AFP::FixedFormat->new( [ $class->formats ] );
    my $packer = Parse::AFP::FixedFormat->new( [ $class->pack_formats ] );
    *{"$class\::parser"} = sub { $parser };
    *{"$class\::packer"} = sub { $packer };
    *{"$class\::field_parser"} = sub { $field_parser{$_[1]} };
    *{"$class\::field_packer"} = sub { $field_packer{$_[1]} };
    *{"$class\::has_field"} = sub { $field_packer{$_[1]} };

    foreach my $field (@fields) {
	next if defined &{"$class\::$field"};
	if ($field eq 'Data' and my $encoding = $class->ENCODING) {
	    require Encode;

	    *{"$class\::$field"} = sub {
		my ($self) = @_;
		(exists $self->{Struct}{$field})
		    ? Encode::decode($encoding => $self->{Struct}{$field})
		    : undef;
	    };
	    *{"$class\::Set$field"} = sub {
		my ($self, $data) = @_;
		$self->{Struct}{$field} = (
		    defined($data)
			? Encode::encode($encoding => $data)
			: undef
		);
	    };
	    next;
	}

	*{"$class\::$field"} = sub {
	    my ($self) = @_;
	    (exists $self->{Struct}{$field}) ? $self->{Struct}{$field} : undef;
	};
	*{"$class\::Set$field"} = sub {
	    my ($self, $data) = @_;
	    $self->{Struct}{$field} = $data;
	};
    }
    ${"$class\::init_done"} = 1;
}

sub new {
    my ($class, $input) = @_;
    $class = ref($class) || $class;
    $class->init;

    my $self = $class->spawn;
    my $data = $self->read_data($input);
    return $self->load($data);
}

sub padding {
    my ($self) = @_;
    my $padding = $self->PADDING;
    return $padding if defined($padding);
    return "\xFF" x $self->member_length_bytes;
}

sub member_length_bytes {
    my ($self) = @_;
    return 0 unless $self->has_members;
    $self->field_format('MemberData') =~ m{(\S+)/} or return;
    return length(pack($1, 0));
}

sub load_struct {
    my ($self, $data) = @_;
    local $SIG{__WARN__} = sub {};
    $self->{Struct} = $self->parser->unformat($$data . $self->padding);
}

sub load_length {
    my ($self) = @_;
    if (exists $self->{Struct}{Length}) {
	$self->{Struct}{Length} += $self->field_length('Length');
    }
}

sub load {
    my ($self, $data) = @_;
    return $self unless defined $data;

    $self->load_struct($data);
    $self->load_length;

    if (my $field = $self->dispatch_field) {
	my $value = $self->$field;
	if (my $subclass = $self->dispatch_class($value)) {
	    $self->load_module($subclass);
	    return $subclass->new($data);
	}
    }

    $self->make_members;
    return $self;
}

sub spawn {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    if (my $subclass = $self->classname($args{Class})) {
	delete $args{Class};
	$self->load_module($subclass);
	return $subclass->spawn(%args);
    }

    return bless({}, $class) unless %args;

    my %hash;
    $args{Length} ||= 0;
    foreach my $field ($self->fields) {
	$hash{$field} = $args{$field};
    }

    foreach my $super_class ($class->superclasses) {
	my $field = $super_class->dispatch_field or next;
	my $table = $super_class->dispatch_table or next;
	next if defined $hash{$field};
	foreach my $code (sort keys %$table) {
	    $class->is_type($table->{$code}) or next;
	    $hash{$field} = $code;
	    last;
	}
    }

    my $obj = bless({ Struct => \%hash }, $class);
    $obj->refresh;
    return $obj;
}

sub prepend_obj {
    my ($self, %args) = @_;
    my $obj = $self->spawn(%args);
    my $parent = $obj->{Parent} = $self->parent;

    $parent->set_members(
	map { (($_ == $self) ? $obj : ()), $_ } $parent->members
    );
    return $obj;
}

sub append_obj {
    my ($self, %args) = @_;
    my $obj = $self->spawn(%args);
    my $parent = $obj->{Parent} = $self->parent;

    $parent->set_members(
	map { $_, (($_ == $self) ? $obj : ()) } $parent->members
    );
    return $obj;
}

sub remove {
    my ($self, %args) = @_;
    $self->parent->set_members(
	grep { ($_ != $self) } $self->parent->members
    );
}

sub parent {
    my ($self) = @_;
    $self->{Parent};
}

sub read_data {
    my ($self, $data) = @_;
    return undef unless defined $data;

    $data = read_file(
	$data,
	scalar_ref => 1,
	binmode => ':raw'
    ) unless ref($data);
    return $data;
}

sub has_members {
    my ($self) = @_;
    return $self->can('MemberData');
}

sub make_members {
    my ($self) = @_;
    return unless $self->has_members;

    my $format = $self->field_pack_format('MemberData');
    $self->set_members(
	map { $self->new_member( \pack($format, @$_) ) }
	$self->validate_memberdata,
    );
}

sub validate_memberdata {
    my ($self) = @_;
    my @members = grep $self->valid_memberdata($_), @{$self->MemberData};
    $self->SetMemberData( \@members );
    return @members;
}

sub set_members {
    my ($self, @members) = @_;
    @{$self->{Members}||=[]} = @members;
}

sub members {
    my ($self, $type) = @_;
    return () unless $self->has_members;
    return grep { $type ? $_->is_type($type) : 1 } @{$self->{Members}||[]};
}

sub members_recursive {
    my ($self, $type) = @_;
    return ( $self->is_type($type) ? $self : () ) unless $self->has_members;
    return map { $_->members_recursive($type) } @{$self->{Members}||[]};
}

sub new_member {
    my ($self, $data) = @_;
    my $obj = $self->member_class->new($data);
    $obj->{Parent} = $self;
    return $obj;
}

sub valid_memberdata { length($_[1][0]) }

sub dump {
    my ($self) = @_;
    return $self->packer->format($self->{Struct})
	unless $self->has_members;

    my $out = '';
    foreach my $field ($self->fields) {
	my $packer = $self->field_packer($field);

	if ($field eq 'MemberData') {
	    my $format = $packer->{Format}[0];
	    my $prefix = ($format =~ m{\((.*?)/}) ? $1 : '';
	    my $length = $self->member_length_bytes;

	    foreach my $member (@{$self->MemberData}) {
		my $rv = $packer->format({ MemberData => $member });
		if ($prefix) {
		    my @leading = unpack($prefix, $rv);
		    $leading[-1] += $length;
		    my $leading = pack($prefix, @leading);
		    substr($rv, 0, length($leading), $leading);
		}
		$out .= $rv;
	    }
	}
	else {
	    $out .= $packer->format($self->{Struct});
	}
    }
    return $out;
}

sub write {
    my ($self, $file) = @_;
    if (ref($file)) {
	$$file = $self->dump;
    }
    else {
	write_file($file, $self->dump);
    }
}

sub superclasses {
    my ($self) = @_;
    my $class = ref($self) || $self;

    no strict 'refs';
    return @{"$class\::ISA"};
}

sub is_type {
    my ($self, $type) = @_;
    my $class = ref($self) || $self;

    $type =~ s/[^\w:]//g;
    return 1 if ($class =~ /::$type$/);

    no strict 'refs';
    foreach my $super_class ($class->superclasses) {
	return 1 if $super_class->is_type($type);
    };
}

sub refresh {
    my ($self) = @_;

    if ($self->has_members) {
	my $parser = $self->field_parser('MemberData');
	my $padding = $self->padding;

	local $SIG{__WARN__} = sub {};
	$self->SetMemberData( [
	    map {
		$parser->unformat( $_->dump . $padding)->{MemberData}[0]
	    } $self->members
	] );
	$self->validate_memberdata;
    }

    if ($self->has_field('Length')) {
	my $length = length($self->dump);
	foreach my $field ($self->fields) {
	    last if $field eq 'Length';
	    $length -= $self->field_length($field);
	}
	$self->SetLength($length);
    }

    my $parent = $self->parent or return;
    $parent->refresh;
}

1;
