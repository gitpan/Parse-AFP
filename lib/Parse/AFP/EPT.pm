# $File: /local/member/autrijus/Parse-AFP//lib/Parse/AFP/EPT.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 3918 $ $DateTime: 2004-02-17T10:05:07.533350Z $

package Parse::AFP::EPT;
use base 'Parse::AFP::Record';

use constant SUBFORMAT => (
    Data => 'a*',    # XXX - not parsed yet
);

1;
