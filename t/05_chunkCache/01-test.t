#should I use -
#T
use FindBin;
print "$FindBin::Bin";
use lib "$FindBin::Bin/../../lib";
use Test::More tests => 6;
use HTTP::OAI::DataProvider::ChunkCache;

my $cache = new HTTP::OAI::DataProvider::ChunkCache( maxSize => 1000 );

    #just dies which is no good
	my $chunk = {};
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );
	$chunk->{token} = '1234';
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );
	$chunk->{chunkNo} = '1';
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );
	$chunk->{maxChunkNo} = '10';
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );
	$chunk->{next} = '1235';
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );
	$chunk->{sql} = 'SELECT X FROM Y';
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );

exit 0;

{
	my $chunk = {
		token      => '1234',
		maxChunkNo => 10,
		'next'     => '1235',
		sql        => 'SELECT X FROM Y',
		total      => '100000'
	};
	ok( $cache->add($chunk) ne 1, 'fail on incomplete chunk' );
}

{
	my $chunk = {
		token      => '1234',
		chunkNo    => 1,
		maxChunkNo => 10,
		'next'     => '1235',
		sql        => 'SELECT X FROM Y',
		total      => '100000'
	};

	$cache->add($chunk);
	ok( $cache->add($chunk) eq 1, 'pass on complete chunk' );
}

{
	my $chunk = $cache->get(1234);
	ok( $chunk->{maxChunkNo} eq '10',              'test maxChunkNo' );
	ok( $chunk->{'next'}     eq '1235',            'test next' );
	ok( $chunk->{sql}        eq 'SELECT X FROM Y', 'test sql' );
	ok( $chunk->{total}      eq '100000',          'test total' );
}

{
	my $cur = $cache->count;
	my $max = $cache->size;
	print "cur:$cur // max:$max\n";

}

{
	my $chunk = {
		token      => '1235',
		chunkNo    => 1,
		maxChunkNo => 10,
		'next'     => '1235',
		sql        => 'SELECT X FROM Y',
		total      => '100000'
	};
	$cache->add($chunk) or die "Cannot add chunk description";
}

#todo turn into a test
{
	$max = $cache->size;
	$cur = $cache->count;
	print "cur:$cur // max:$max\n";
	foreach ( $cache->list ) {
		print "list:$_\n";
	}
}

#TODO
#write a test that checks if old items are deleted if threshold is reached
#TODO: Should I use error message @! instead of carp or what ?

