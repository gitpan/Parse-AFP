# $File: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/MCF.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 1130 $ $DateTime: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::MCF;
use base 'Parse::AFP::Record';

use constant SUBFORMAT => (
    'MCF::DataGroup'	=> ['n/a* XX', '*'],
);

1;
