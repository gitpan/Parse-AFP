# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::Triplet;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    Length	=> 'C',	    # length() + 2
    Type	=> 'H2',
    Data	=> 'a*',
);
use constant DISPATCH_FIELD => 'Type';
use constant DISPATCH_TABLE => (
    '02'	=> 'Triplet::FQN',  # Fully Qualified Name
    '24'	=> 'Triplet::RLI',  # Resource Local Identifier
);

1;
