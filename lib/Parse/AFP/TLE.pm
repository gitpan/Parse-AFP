# $File: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/TLE.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 1130 $ $DateTime: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::TLE;
use base 'Parse::AFP::Record';

1;
__END__

use constant SUBFORMAT => (
    'Triplet'   => [ 'C/a* X', '*' ],
    XUnitBase		=> 'C',
    YUnitBase		=> 'C',
    XLUnitsperUnitBase	=> 'n',
    YLUnitsperUnitBase	=> 'n',
    XPageSize		=> 'H6',
    YPageSize		=> 'H6',
    _			=> 'a*',
);

1;
