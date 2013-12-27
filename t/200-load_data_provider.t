#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider' ) || print "Bail out!
";
}

diag( "Testing HTTP::OAI::DataProvider $HTTP::OAI::DataProvider::VERSION, Perl $], $^X" );
