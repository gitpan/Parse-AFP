# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::PTX;
use base 'Parse::AFP::Record';

use constant SUBFORMAT => (
    EscapeSequence => 'H4',	# 2BD3
    'PTX::ControlSequence' => ['C/a* X', '*'],
);

sub refresh {
    my ($self) = @_;

    foreach my $member ($self->members) {
	$member->SetControlCode(
	    unpack('H2', pack('H2', $member->ControlCode) | "\x01")
	);
    }

    if (my $last_member = ($self->members)[-1]) {
	$last_member->SetControlCode(
	    unpack('H2', pack('H2', $last_member->ControlCode) ^ "\x01")
	);
    }

    $self->SUPER::refresh;
}

sub load_struct {
    my ($self, $data) = @_;
    # XXX - first get the header, then split with 2BD3,
    # then do a step-by-step tokenization to make sure
    # raw text fields get respected
    $self->set_struct( $self->parser->unformat($$data . $self->padding) );
}

1;
