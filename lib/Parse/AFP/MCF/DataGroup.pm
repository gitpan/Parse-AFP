# $File: //member/autrijus/.vimrc $ $Author: autrijus $
# $Revision: #14 $ $Change: 4137 $ $DateTime: 2003/02/08 11:41:59 $

package Parse::AFP::MCF::DataGroup;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    Length	=> 'n',
    'Triplet'	=> [ 'C/a* X', '*' ],
);

1;
