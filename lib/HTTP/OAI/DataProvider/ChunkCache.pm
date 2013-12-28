package HTTP::OAI::DataProvider::ChunkCache;
{
  $HTTP::OAI::DataProvider::ChunkCache::VERSION = '0.009';
}
use strict;
use warnings;

# ABSTRACT: Store request info per resumptionToken

use Moose;
use namespace::autoclean;
use Carp qw/carp croak/;
use HTTP::OAI::DataProvider::ChunkCache::Description;
#use HTTP::OAI::DataProvider::Common qw/Debug Warning/;
our $chunkCache = {};
has 'maxSize' => ( is => 'ro', isa => 'Int', required => '1' );


sub add {
	my $self = shift or croak "Need myself";
	my $chunkDesc = shift or croak "Need chunkDescription!";    #should be return

	if ( !ref $chunkDesc ) {
		croak "chunk Description is wrong format!";
	}

	if ( $chunkDesc->maxChunkNo > $self->maxSize ) {
		croak "maxChunkNo greater than chunkCache maxSize";
	}

	#necessary remove a description from cache
	my $count   = $self->count();
	my $overPar = $count + 1 - $self->{maxSize};
	if ( $overPar > 0 ) {
		$self->_rmFromCache($overPar);
	}

	#write into cache
	#Debug '==============adding chunk '.$chunkDesc->{token};
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
	my $self = shift or croak "Need myself";
	my $token = shift or return;

	if ( !$chunkCache->{$token} ) {
		my $msg="Token $token not found in chunk cache";
		#use Data::Dumper;
		#Debug $chunkCache;
		$self->{error} = $msg;
		#Debug $msg;
		return;
	}

	return $chunkCache->{$token};
}


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
		#Debug "==============rming chunk $key";
		delete $chunkCache->{$key};
		$i++;
	}
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

HTTP::OAI::DataProvider::ChunkCache - Store request info per resumptionToken

=head1 VERSION

version 0.009

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::ChunkCache;
	my $cache=new HTTP::OAI::DataProvider::ChunkCache (maxSize=>$integer);

	#chunkDesc is a chunk described as hashref
	#Last description doesn't have a next
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

=head2 my $integer=$cache->count;

Returns the number of items in cache. See also $cache->size

=head2 my $msg=$cache->error;

Returns last error message. Usage example:

	$cache->add($chunk_descr) or die $cache->error;

=head2 my $chunk=$chunkCache->get($token);

Returns a HTTP::OAI::DataProvider::ChunkCache::Description object or nothing. 

Nothing is return if no token is supplied or when no matching description was
found.

=head2 my @tokens=$cache->list;

Returns an array of tokens in the cache (in no particular order).

Todo: What do on error?

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
