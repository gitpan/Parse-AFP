# $File: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/MCF/DataGroup.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 1130 $ $DateTime: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::MCF::DataGroup;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    Length	=> 'n',
    'Triplet'	=> [ 'C/a* X', '*' ],
);

1;
