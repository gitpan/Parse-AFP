# $URL$ $Author$
# $Rev$ $Date$

package Parse::AFP::PTX::ControlSequence;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    Length	=> 'C',
    ControlCode	=> 'H2',
    Data	=> 'a*',
);
use constant DISPATCH_FIELD => 'ControlCode';
use constant DISPATCH_TABLE => (
    f0	=> 'PTX::SCFL',
    f1	=> 'PTX::SCFL',
    da	=> 'PTX::TRN',
    db	=> 'PTX::TRN',
);

1;
