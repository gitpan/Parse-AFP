# $File: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/MCF1.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 1130 $ $DateTime: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::MCF1;
use base 'Parse::AFP::Record';

use constant SUBFORMAT => (
    RepeatingGroupLength    => 'C',
    _			    => 'a3',
    'MCF1::DataGroup'	    => ['a{$RepeatingLength}', '*'],
);

1;
