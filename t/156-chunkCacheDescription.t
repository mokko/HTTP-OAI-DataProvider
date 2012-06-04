use strict;
use warnings;
use Test::More tests => 2;
use Scalar::Util qw(blessed);

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::ChunkCache::Description' ) || print "Bail out!
";
}

my $desc = new HTTP::OAI::DataProvider::ChunkCache::Description(
	chunkNo      => '1',
	maxChunkNo   => '10',
	sql          => 'SELECT * from Y',
	targetPrefix => 'oai',
	total        => '1000',
	token        => 'token',
);

ok (blessed $desc eq 'HTTP::OAI::DataProvider::ChunkCache::Description', 'new made right type');







