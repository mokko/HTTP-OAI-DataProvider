package HTTP::OAI::DataProvider::ChunkCache;

# ABSTRACT: Store request info per resumptionToken

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Carp qw/carp croak/;
use HTTP::OAI::DataProvider::ChunkCache::Description;

our $chunkCache = {};
has 'maxSize' => ( is => 'ro', isa => 'Int', required => '1' );

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::ChunkCache;
	my $cache=new HTTP::OAI::DataProvider::ChunkCache (maxSize=>$integer);

	#chunkDesc is description of a chunk as hashref
	#next is optional. Last token doesn't have a next
	my $chunkDesc= new HTTP::OAI::DataProvider::ChunkCache::Description(
		chunkNo=>$chunkNo,
		maxChunkNo=>$maxChunkNo,
		[next=>$token,]
		sql=>$sql,
		token=>$token,
		total=>$total,
	);

	#add a chunkDesc to cache
	$cache->add ($chunkDesc) or die $cache->error;

	#get a chunk from cache
	my $chunkDesc=$cache->get ($token); #chunk is hashref

	#size/maxSize
	my $current_size=$cache->count;
	my $max=$cache->size;

	my @tokens=$cache->list;	#list tokens

=head2 my $chunkCache=HTTP::OAI::DataProvider::ChunkCache::new (maxSize=>1000);

=head2 $chunkCache->add(%chunk);

Add chunk information to the cache. Add will delete old chunks if no of cached
chunks would exceed maxSize after adding it. On error: carps and returns 0.
Return 1 on success.

=cut

sub add {
	my $self = shift;
	my $chunkDesc = shift or croak "Need chunkDescription!";    #should be return

	if ( !ref $chunkDesc ) {
		croak "chunk Description is wrong format!";
	}

	if ( $chunkDesc->maxChunkNo > $self->maxSize ) {
		croak "maxChunkNo greater than chunkCache maxSize";
	}

	#if necessary remove a description from cache
	my $count   = $self->count();
	my $overPar = $count + 1 - $self->{maxSize};
	if ( $overPar > 0 ) {
		$self->_rmFromCache($overPar);
	}

	#write into cache
	$chunkCache->{ $chunkDesc->{token} } = $chunkDesc;
}

=head2 my $integer=$cache->count;

Returns the number of items in cache. See also $cache->size

=cut

sub count {
	return scalar keys %{$chunkCache};
}

=head2 my $msg=$cache->error;

Returns last error message. Usage example:

	$cache->add($chunk_descr) or die $cache->error;

=cut

sub error {
	my $self = shift;
	if ( $self->{error} ) {
		return $self->{error};
	}
}

=head2 my $chunk=$chunkCache->get($token);

Returns a HTTP::OAI::DataProvider::ChunkCache::Description object or nothing. 

Nothing is return if no token is supplied or when no matching description was
found.

=cut

sub get {
	my $self = shift;
	my $token = shift or return;

	if ( !$chunkCache->{$token} ) {
		$self->{error} = "This token does not exist in cache";
		return;
	}

	return $chunkCache->{$token};
}

=head2 my @tokens=$cache->list;

Returns an array of tokens in the cache (in no particular order).

Todo: What do on error?

=cut

sub list {
	return ( keys %{$chunkCache} );
}

#
# PRIVATE
#

sub _rmFromCache {    #gets called in add
	my $self    = shift;
	my $overPar = shift;

	#@array has chunks ordered according to their age
	my @array = sort keys %{$chunkCache};

	my $i = 0;
	while ( $i < $overPar ) {
		my $key = shift @array;
		delete $chunkCache->{$key};
		$i++;
	}
}

__PACKAGE__->meta->make_immutable;
1;
