#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::ChunkCache' ) || print "Bail out!
";
}


