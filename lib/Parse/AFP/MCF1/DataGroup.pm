# $File: //local/member/autrijus/Parse-AFP/lib/Parse/AFP/MCF1/DataGroup.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 1130 $ $DateTime: 2004-02-17T15:40:29.640821Z $

package Parse::AFP::MCF1::DataGroup;
use base 'Parse::AFP::Base';

use constant FORMAT => (
    CodedFontLocalId		=> 'C',
    _				=> 'a',
    CodedFontResourceSectionId	=> 'C',
    _				=> 'a',
    CodedFontName		=> 'a8',
    CodePageName		=> 'a8',
    FontCharacterSetName	=> 'a8',
    CharacterRotation		=> 'n',
);
use constant ENCODED_FIELD => ('CodedFontName');
use constant ENCODING => 'cp500';

1;
