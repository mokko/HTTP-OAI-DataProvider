package HTTP::OAI::DataProvider::ChunkCache;
BEGIN {
  $HTTP::OAI::DataProvider::ChunkCache::VERSION = '0.006';
}
# ABSTRACT: Store request info per resumptionToken

use strict;
use warnings;
use Carp qw/carp croak/;

our $chunkCache = {};



sub new {
	my $class = shift;
	my $self  = {};
	my %args  = @_;

	if ( $args{maxSize} ) {
		$self->{maxSize} = $args{maxSize};
	} else {
		croak "Need maxSize for cache";
	}

	bless $self, $class;
	return $self;
}


sub add {
	my $self  = shift;
	my $chunkDesc = shift;

	#ensure that necessary info is there
	#next is option since last chunk has no next
	foreach (qw /chunkNo maxChunkNo sql targetPrefix total token/) {
		if ( !$chunkDesc->{$_} ) {
			croak "$_ missing";
			$self->error++;
		}
	}


	if ($chunkDesc->{maxChunkNo} > $self->{maxSize}) {
		croak "maxChunkNo greater than chunkCache maxSize";
	}

	if ($self->error) {
		return 1;
	}

	#write into cache
	$self->_cacheSize();
	$chunkCache->{ $chunkDesc->{token} } = $chunkDesc;
}


sub count {
	return scalar keys %{$chunkCache};
}


sub error {
	my $self = shift;
	if ( $self->{error} ) {
		return $self->{error};
	}
}


sub get {
	my $self  = shift;
	my $token = shift;

	if ( !$token ) {
		$self->{error} = "No token specified when \$cache->get() was called";
		return ();
	}

	if ( !$chunkCache->{$token} ) {
		$self->{error} = "This token does not exist in cache";
		return();
	}

	return $chunkCache->{$token};

}


sub list {
	my $self = shift;
	return ( keys %{$chunkCache} );
}


sub size {
	my $self = shift;
	my $size=shift;

	#i am not sure what scalar does
	if ($size) {
		$self->{maxSize} = scalar $size;
	} else {
		return $self->{maxSize};
	}
}

#
# PRIVATE
#

#gets called in add
sub _cacheSize {
	my $self  = shift;
	my $count = $self->count();

	#called before we add an item to cache, so we have to add one to the count
	#overPar: no of items which cache exceeds maxSize, should max be 1
	my $overPar = $count + 1 - $self->{maxSize};
	if ( $overPar > 0 ) {
		$self->_rmFromCache($overPar);
	}
}

#gets called in _cacheSize
sub _rmFromCache {
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

1;

__END__
=pod

=head1 NAME

HTTP::OAI::DataProvider::ChunkCache - Store request info per resumptionToken

=head1 VERSION

version 0.006

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::ChunkCache;
	my $cache=new HTTP::OAI::DataProvider::ChunkCache (maxSize=>$integer);

	#chunkDesc is description of a chunk as hashref
	#next is optional. Last token doesn't have a next
	my $chunkDesc={
		chunkNo=>$chunkNo,
		maxChunkNo=>$maxChunkNo,
		[next=>$token,]
		sql=>$sql,
		token=>$token,
		total=>$total,
	};

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

=head2 my $integer=$cache->count;

Returns the number of items in cache. See also $cache->size

=head2 my $msg=$cache->error;

Returns last error message. Usage example:

	$cache->add($chunk_descr) or die $cache->error;

=head2 my $chunk=$chunkCache->get($token);

Returns a chunk description as hashref or nothing on error.

Structure of hashref:
	$chunk={
			chunkNo=>$chunkNo,
			maxChunkNo=>$maxChunkNo,
			next=>$token,
			sql=>$sql,
			targetPrefix=>$prefix,
			token=>$token,
			total=>$total
	};

Of course, it is not a chunk (i.e. results), but the description of a chunk.

=head2 my @tokens=$cache->list;

Returns an array of tokens in the cache (in no particular order).

Todo: What do on error?

=head2 my $maxSize=$cache->size;

Gets or sets maximum size of cache.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

