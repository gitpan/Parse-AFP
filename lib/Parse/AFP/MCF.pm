# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::MCF;
use base 'Parse::AFP::Record';

use constant SUBFORMAT => (
    MemberData	    => ['n/a* XX', '*'],
);
use constant MEMBER_CLASS => 'MCF::DataGroup';

1;
