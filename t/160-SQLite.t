use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::SQLite' ) || print "Bail out!
";
}

use HTTP::OAI::DataProvider::SQLite;

ok(1,'bla');