package HTTP::OAI::DataProvider::Engine;
# ABSTRACT: interface between data store and data provider
use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Time::HiRes qw(gettimeofday);    #to generate unique tokens
use Carp qw(carp croak);
use HTTP::OAI::DataProvider::Common qw/Debug Warning/;

=head1 TODO

We want some better abstraction, so we need two classes.
a) everything that actually talks to the DB (SQLite in this case) is called 
   'basic'.
b) Everything that consists of calls to basic methods, but doesn't require
   direct communication is called 'complex'.

At the end of the day, we need only basic methods in SQLite. Complex stuff can
go in the Engine. The generic Engine will require the rest with as per role
I assume.

Basic stuff:
	my $granularity=$engine->granularity();
	my $date=$engine->earliestDate();
Complex (generic engine)

=head2 SYNOPSIS

What does the engine need?

	my $header=findByIdentifier ($identifier);
	my $granuality=$engine->granularity();
	my @used_sets=$engine->listSets();

	my $result=$engine->queryHeaders ($params);
	my $result=$engine->queryRecords ($params);

=head2 my $token=$engine->mkToken;

Returns a fairly arbitrary unique token (miliseconds since epoch). 

=cut

sub mkToken {
	my ( $sec, $msec ) = gettimeofday;
	return time . $msec; 
}

=head2 my $chunk_size=$result->chunkSize;

Return chunk_size if defined or empty. Chunk_size is a config value that
determines how big (number of records per chunk) the chunks are.

=cut

sub chunkSize {
	my $self = shift;
	Debug "chunkSize" . $self->{chunkSize};
	if ( $self->{chunkSize} ) {
		return $self->{chunkSize};
	}
}

=head1 BASIC PARAMETER VALIDATION

While we are waiting that perl gets method signatures (see Method::Sigatures),
we work with very simple hand-made parameter validation.

=head2 $self->requireAttributes ($hashref, 'a', b');

Feature is a key of a hashref, either the object itself or another hashref
object.

Croaks if a or b are not present. If hashref is omitted, checks in $self:
	$self->requireAttributes ('a', b');

=cut

sub requireAttributes {
	my $self = shift;    #hashref
	if (ref $_[0] eq 'HASH') {
		my $args = shift;
		foreach my $key (@_) {
			if ( !$args->{$key} ) {
				croak "Attribute $key missing";
			}
		}
	} else {
		foreach my $key (@_) {
			if ( !$self->{$key} ) {
				croak "Attribute $key missing";
			}
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;   
