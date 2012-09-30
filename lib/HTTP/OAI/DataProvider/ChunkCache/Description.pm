package HTTP::OAI::DataProvider::ChunkCache::Description;
{
  $HTTP::OAI::DataProvider::ChunkCache::Description::VERSION = '0.007';
}

# ABSTRACT: Store request info per resumptionToken

use strict;
use warnings;
use Moose;
use Carp qw/carp croak/;
use namespace::autoclean;

has 'chunkNo'      => ( is => 'ro', isa => 'Int', required => '1' );
has 'maxChunkNo'   => ( is => 'ro', isa => 'Int', required => '1' );
has 'sql'          => ( is => 'ro', isa => 'Str', required => '1' );
has 'token'        => ( is => 'ro', isa => 'Str', required => '1' );
has 'total'        => ( is => 'ro', isa => 'Str', required => '1' );
has 'targetPrefix' => ( is => 'ro', isa => 'Str', required => '1' );
has 'next' => ( is => 'rw', isa => 'Str', required => '0' );
has 'last' => ( is => 'rw', isa => 'Str', required => '0' );
has 'requestURL' => ( is => 'rw', isa => 'Str', required => '0' );




__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

HTTP::OAI::DataProvider::ChunkCache::Description - Store request info per resumptionToken

=head1 VERSION

version 0.007

=head1 METHODS

=head2 my $desc=new HTTP::OAI::DataProvider::ChunkCache::Description(%OPTS);

 my $desc= new HTTP::OAI::DataProvider::ChunkCache::Description(
		chunkNo=>$chunkNo,
		maxChunkNo=>$maxChunkNo,
		[next=>$token,]
		sql=>$sql,
		token=>$token,
		total=>$total,
	);

=over

=item * chunkNo: unique index of this chunk

=item * maxChunkNo: the highest chunk from this request

=item * token: token of this chunk

=item * next: the token of the next chunk, if any (optional).

=item * total: don't remember what this is

=back

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

