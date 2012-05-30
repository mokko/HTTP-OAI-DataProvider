#should I use -
#T
use strict;
use warnings;
use FindBin;
use Test::More tests => 10;
use HTTP::OAI::DataProvider::ChunkCache;
use HTTP::OAI::DataProvider::ChunkCache::Description;

my $soll = 1000;

#
# 1 - new, maxSize
#

{
	eval { my $cache = new HTTP::OAI::DataProvider::ChunkCache(); };
	ok( $@, 'expect new to fail' );
}
my $cache = new HTTP::OAI::DataProvider::ChunkCache( maxSize => $soll );

#ok($got eq $expected, $test_name);
ok( ref $cache eq 'HTTP::OAI::DataProvider::ChunkCache', 'cache exists' );
ok( $cache->{maxSize} == $soll, 'maxSize right' );

#
# 2 - add, count
#

eval { $cache->add(); };
ok( $@, 'add() should not pass' );

eval { $cache->add( a => 'b' ); };
ok( $@, 'add() should not pass' );

my $desc = new HTTP::OAI::DataProvider::ChunkCache::Description(
	chunkNo      => '1',
	maxChunkNo   => '10',
	sql          => 'SELECT * from Y',
	targetPrefix => 'oai',
	total        => '1000',
	token        => 'token',
);
ok( $cache->count() == 0, 'count when empty' );
eval { $cache->add($desc); };
ok( !$@, 'add($desc) should pass' );

# currently add never raises an error value; it croaks instead
ok( $cache->count() == 1, 'count again' );

#
# 3 - get
#

ok( !$cache->get('nonsenseToken'), 'get should return false' );

my $newDesc = $cache->get('token');
ok( cmpHashrefs( $desc, $newDesc ), 'result looks good' );




#
# SUBS
#
#i don't want to load another module for that. Should I put it in DP::Test?
sub cmpHashrefs {
	  my $first = shift or die "Need first!";
	  my $sec   = shift or die "Need sec!";

	  foreach my $key ( keys %{$first} ) {
		  if ( !$sec->{$key} ) {
			  return;    #error
		  }
		  else {
			  if ( $first->{$key} ne $sec->{$key} ) {
				  return;    #error
			  }
		  }
	  }
	  return 1;    #success
}

