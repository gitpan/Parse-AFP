# $URL: /local/member/autrijus/Parse-AFP//lib/Parse/AFP/Triplet/FQN.pm $ $Author: autrijus $
# $Rev: 3917 $ $Date: 2004-02-17T07:03:18.734947Z $

package Parse::AFP::Triplet::FQN;
use base 'Parse::AFP::Triplet';

use constant SUBFORMAT => (
    SubType	=> 'H2',
    Format	=> 'H2',
    Data	=> 'a*',
);
use constant ENCODING => 'cp500';

1;
