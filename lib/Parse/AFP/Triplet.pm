# $File: /local/member/autrijus/Parse-AFP//lib/Parse/AFP/Triplet.pm $ $Author: autrijus $
# $Revision: #7 $ $Change: 3918 $ $DateTime: 2004-02-17T10:05:07.533350Z $

package Parse::AFP::Triplet;
use base 'Parse::AFP::Base';
use constant FORMAT => (
    Length	=> 'C',	    # length() + 2
    Type	=> 'H2',
    Data	=> 'a*',
);
use constant DISPATCH_FIELD => 'Type';
use constant DISPATCH_TABLE => (
    '01' => 'Triplet::CGCSGI',	# Coded Graphic Character Set Global ID
    '02' => 'Triplet::FQN',	# Fully Qualified Name
    '04' => 'Triplet::MO',	# Mapping Option
    '10' => 'Triplet::OCL',	# Object Classification
    '18' => 'Triplet::MIS',	# MO:DCA Interchange Set
    '1d' => 'Triplet::TO',	# Text Orientation (R)
    '1f' => 'Triplet::FDS',	# Font Descriptor Specification
    '20' => 'Triplet::FCGCSGI',	# Font Coded Graphic Character Set Global Identifier
    '21' => 'Triplet::OFSS',	# Object Function Set Specification
    '21' => 'Triplet::ROT',	# Resource Object Type (R)
    '22' => 'Triplet::ERLI',	# Extended Resource Local ID
    '24' => 'Triplet::RLI',	# Resource Local ID
    '25' => 'Triplet::RSN',	# Resource Section Number
    '26' => 'Triplet::CR',	# Character Rotation
    '27' => 'Triplet::LDOPM',	# Line Data Object Position Migration (R)
    '2d' => 'Triplet::OBO',	# Object Byte Offset
    '36' => 'Triplet::AV',	# Attribute Value
    '43' => 'Triplet::DP',	# Descriptor Position
    '45' => 'Triplet::MEC',	# Media Eject Control
    '46' => 'Triplet::POCP',	# Page Overlay Conditional Processing
    '47' => 'Triplet::RUA',	# Resource Usage Attribute
    '4b' => 'Triplet::OAMU',	# Object Area Measurement Units
    '4c' => 'Triplet::OAS',	# Object Area Size
    '4d' => 'Triplet::AD',	# Area Definition
    '4e' => 'Triplet::CS',	# Color Specification
    '50' => 'Triplet::ESI',	# Encoding Scheme ID
    '56' => 'Triplet::MMPN',	# Medium Map Page Number
    '57' => 'Triplet::OBE',	# Object Byte Extent
    '58' => 'Triplet::OSFO',	# Object Structured Field Offset
    '59' => 'Triplet::OSFE',	# Object Structured Field Extent
    '5a' => 'Triplet::OO',	# Object Offset
    '5d' => 'Triplet::FHSF',	# Font Horizontal Scale Factor
    '5e' => 'Triplet::OCO',	# Object Count
    '62' => 'Triplet::LDTS',	# Local Date and Time Stamp
    '63' => 'Triplet::OCH',	# Object Checksum (R)
    '64' => 'Triplet::OOI',	# Object Origin Identifier (R)
    '65' => 'Triplet::C',	# Comment
    '68' => 'Triplet::MOR',	# Medium Orientation
    '6c' => 'Triplet::ROI',	# Resource Object Include
    '70' => 'Triplet::PSRM',	# Presentation Space Reset Mixing
    '71' => 'Triplet::PSMR',	# Presentation Space Mixing Rules
    '72' => 'Triplet::UDTS',	# Universal Date and Time Stamp
    '73' => 'Triplet::II',	# IMM Insertion (R)
    '74' => 'Triplet::TS',	# Toner Saver
    '75' => 'Triplet::CF',	# Color Fidelity
    '78' => 'Triplet::FF',	# Font Fidelity
    '80' => 'Triplet::AQ',	# Attribute Qualifier
    '81' => 'Triplet::PPI',	# Page Position Information
    '82' => 'Triplet::PV',	# Parameter Value
    '83' => 'Triplet::PC',	# Presentation Control
    '84' => 'Triplet::FRMT',	# Font Resolution and Metric Technology
    '85' => 'Triplet::FO',	# Finishing Operation
    '87' => 'Triplet::MF',	# Media Fidelity
    '63' => 'Triplet::T1CRMT',	# Type 1 - CRC Resource Management Triplet
    '63' => 'Triplet::T2FRMT',	# Type 2 - Font Resource Management Triplet
    '6d' => 'Triplet::EF',	# Extension Font
    '79' => 'Triplet::MA',	# Metric Adjustment
);

1;
