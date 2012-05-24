#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::Valid' ) || print "Bail out!
";
}

diag( "Testing HTTP::OAI::DataProvider::Valid $HTTP::OAI::DataProvider::Valid::VERSION, Perl $], $^X" );
