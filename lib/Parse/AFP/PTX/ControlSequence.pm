# $URL: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/PTX/ControlSequence.pm $ $Author: autrijus $
# $Rev: 1130 $ $Date: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::PTX::ControlSequence;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    Length	=> 'C',
    ControlCode	=> 'H2',
    Data	=> 'a*',
);
use constant DISPATCH_FIELD => 'ControlCode';
use constant DISPATCH_TABLE => (
    c0	=> 'PTX::SIM',	    c1	=> 'PTX::SIM',	    # Set Inline Margin
    c6	=> 'PTX::AMI',	    c7	=> 'PTX::AMI',	    # Absolute Move Inline
    d0	=> 'PTX::SBI',	    d1	=> 'PTX::SBI',	    # Set Baseline Increment
    d2	=> 'PTX::AMB',	    d3	=> 'PTX::AMB',	    # Absolute Move Baseline
    d9	=> 'PTX::BLN',	    d9	=> 'PTX::BLN',	    # Begin Line Next
    e4	=> 'PTX::DIR',	    e5  => 'PTX::DIR',	    # Draw I-Axis Rule
    e6	=> 'PTX::DBR',	    e7  => 'PTX::DBR',	    # Draw B-Axis Rule
    f0	=> 'PTX::SCFL',	    f1	=> 'PTX::SCFL',	    # Set Coded Font Local
    f6	=> 'PTX::STO',	    f7	=> 'PTX::STO',	    # Set Text Orientation
    da	=> 'PTX::TRN',	    db	=> 'PTX::TRN',	    # Transparent Data
);

1;
