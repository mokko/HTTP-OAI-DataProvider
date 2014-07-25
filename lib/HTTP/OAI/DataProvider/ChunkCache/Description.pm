package HTTP::OAI::DataProvider::ChunkCache::Description;

# ABSTRACT: Store request info per resumptionToken, for pagination

use strict;
use warnings;
use Carp qw/carp croak/;

use Moo;
use MooX::Types::MooseLike::Base qw/Int Str/;

has 'chunkNo'      => ( is => 'ro', isa => Int, required => '1' );
has 'maxChunkNo'   => ( is => 'ro', isa => Int, required => '1' );
has 'sql'          => ( is => 'ro', isa => Str, required => '1' );
has 'token'        => ( is => 'ro', isa => Str, required => '1' );
has 'total'        => ( is => 'ro', isa => Str, required => '1' );
has 'targetPrefix' => ( is => 'ro', isa => Str, required => '1' );
has 'next' => ( is => 'rw', isa => Str, required => '0' );
has 'last' => ( is => 'rw', isa => Str, required => '0' );
has 'requestURL' => ( is => 'rw', isa => Str, required => '0' ); #still necessary?


=method my $desc=new HTTP::OAI::DataProvider::ChunkCache::Description(%OPTS);

 my $desc= HTTP::OAI::DataProvider::ChunkCache::Description->new (
		chunkNo=>$chunkNo,
		maxChunkNo=>$maxChunkNo,
		#next=>$token,
		sql=>$sql,
		token=>$token,
		total=>$total,
	);

=over 

=item * chunkNo: unique index of this chunk

=item * maxChunkNo: the total number of chunks from this request

=item * token: token of this chunk

=item * next: the token of the next chunk, if any (optional).

=item * sql: the sql from this chunk

=item * total: ?

=back

=cut

1;
