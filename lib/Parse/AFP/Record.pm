# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::Record;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    CC		=> 'H2',
    Length	=> 'n',	    # length() + 2
    Type	=> 'H6',
    FlagByte	=> 'a',
    Reserved	=> 'n',
    Data	=> 'a*',
);
use constant DISPATCH_FIELD => 'Type';
use constant DISPATCH_TABLE => (
    d3ab8a	=> 'MCF',
    d3b18a	=> 'MCF1',
    d3ee9b	=> 'PTX',
);

1;
