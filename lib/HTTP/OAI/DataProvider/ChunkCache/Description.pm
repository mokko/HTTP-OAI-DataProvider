package HTTP::OAI::DataProvider::ChunkCache::Description;

# ABSTRACT: Store request info per resumptionToken

use strict;
use warnings;
use Moose;
use Carp qw/carp croak/;
use namespace::autoclean;

has 'chunkNo'    => ( is => 'ro', isa => 'Int', required => '1' );
has 'maxChunkNo' => ( is => 'ro', isa => 'Int', required => '1' );
has 'sql'        => ( is => 'ro', isa => 'Str', required => '1' );
has 'token'      => ( is => 'ro', isa => 'Str', required => '1' );
has 'total'      => ( is => 'ro', isa => 'Str', required => '1' );
has 'next'       => ( is => 'rw', isa => 'Str', required => '0' );

=method my $desc=new HTTP::OAI::DataProvider::ChunkCache::Description(%OPTS);

 my $desc= new HTTP::OAI::DataProvider::ChunkCache::Description(
		chunkNo=>$chunkNo,
		maxChunkNo=>$maxChunkNo,
		[next=>$token,]
		sql=>$sql,
		token=>$token,
		total=>$total,
	);

=list
* chunkNo: unique index of this chunk
* maxChunkNo: the highest chunk from this request
* token: token of this chunk
* next: the token of the next chunk, if any (optional).
* total: don't remember what this is

=cut

__PACKAGE__->meta->make_immutable;
1;
