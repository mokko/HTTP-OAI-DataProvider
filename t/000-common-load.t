#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::Common' ) || print "Bail out!
";
}

diag( "Testing HTTP::OAI::DataProvider::Common $HTTP::OAI::DataProvider::Common::VERSION, Perl $], $^X" );
