#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::SQLite' ) || print "Bail out!
";
}

diag( "Testing HTTP::OAI::DataProvider::SQLite $HTTP::OAI::DataProvider::SQLite::VERSION, Perl $], $^X" );
