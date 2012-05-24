#should I use -
#T
use FindBin;
use Test::More tests => 2;
use HTTP::OAI::DataProvider::ChunkCache;

my $soll = 1000;
my $cache = new HTTP::OAI::DataProvider::ChunkCache( maxSize => $soll );

#ok($got eq $expected, $test_name);
ok( ref $cache eq 'HTTP::OAI::DataProvider::ChunkCache', 'cache exists' );
cmp_ok($cache->{maxSize}, '==', $soll, 'maxSize right');


#diag "maxSIZE".$cache->{maxSize}."\n";

