#!/usr/bin/env perl

use inc::Module::Install;

name		('Parse-AFP');
author		('Autrijus Tang <autrijus@autrijus.org>');
abstract	('IBM Advanced Function Printing Parser');
license		('perl');
version_from	('lib/Parse/AFP.pm');
install_script	($_) for <script/*.pl>;

requires	(
    'perl'	    => '5.8.2',
    'Parse::Binary' => 0.08,
    'Encode::IBM'   => 0.01,
);

WriteAll( sign => 1 );
