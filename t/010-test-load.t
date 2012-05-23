#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::Test' ) || print "Bail out!
";
}

diag( "Testing HTTP::OAI::DataProvider::Test $HTTP::OAI::DataProvider::Test::VERSION, Perl $], $^X" );
