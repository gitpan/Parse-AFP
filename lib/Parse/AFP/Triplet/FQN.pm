# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::Triplet::FQN;
use base 'Parse::AFP::Triplet';

use constant SUBFORMAT => (
    SubType	=> 'H2',
    Format	=> 'H2',
    Data	=> 'a*',
);
use constant ENCODING => 'cp500';

1;
