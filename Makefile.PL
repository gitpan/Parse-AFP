#!/usr/bin/env perl
# $File: //member/autrijus/Win32-Exe/Makefile.PL $ $Author: autrijus $
# $Revision: #2 $ $Change: 9927 $ $DateTime: 2004/02/06 19:31:24 $

use inc::Module::Install;

name		('Parse-AFP');
author		('Autrijus Tang <autrijus@autrijus.org>');
abstract	('IBM Advanced Function Printing Parser');
license		('gpl');
version_from	('lib/Parse/AFP.pm');

requires	(
    'perl'	    => '5.8.2',
    'File::Slurp'   => 0,
);

WriteAll( sign => 1 );
