# $File: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/PGD.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 1130 $ $DateTime: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::PGD;
use base 'Parse::AFP::Record';

use constant SUBFORMAT => (
    XUnitBase		=> 'C',
    YUnitBase		=> 'C',
    XLUnitsperUnitBase	=> 'n',
    YLUnitsperUnitBase	=> 'n',
    XPageSize		=> 'H6',
    YPageSize		=> 'H6',
    _			=> 'a*',
);

1;
