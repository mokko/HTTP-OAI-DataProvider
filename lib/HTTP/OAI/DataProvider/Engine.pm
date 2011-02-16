package HTTP::OAI::DataProvider::Engine;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);    #to generate unique tokens
use Dancer ':syntax';
use Carp qw/croak/;

=head2 Engine Requirements

Engine interfaces the data store on the one side and data provider on the side.

What does the engine need?

	my $header=findByIdentifier ($identifier);
	my $date=$engine->earliestDate();
	my $granuality=$engine->granularity();
	my @used_sets=$engine->listSets();

	my $result=$engine->queryHeaders ($params);
	my $result=$engine->queryRecords ($params);

=cut

=head2 my $cache=new HTTP::OAI::DataRepository::Result (
);
=cut

=head2 my $token=$engine->mkToken;

Returns an arbitrary token. The only problem is that no token should ever
repeat. I could use the current milisecond. That will never repeat, right?
And it should be unique, right?

=cut

sub mkToken {
	my ( $sec, $msec ) = gettimeofday;
	return time . $msec;    #time returns seconds since epoch
}

=head2 my $chunk_size=$result->chunkSize;

Return chunk_size if defined or empty. Chunk_size is a config value that
determines how big (number of records per chunk) the chunks are.

=cut

sub chunkSize {
	my $self = shift;
	debug "chunkSize" . $self->{chunkSize};
	if ( $self->{chunkSize} ) {
		return $self->{chunkSize};
	}
}

=head2 $self->requiredType ('HTTP::OAI::DataProvider');

Tests if $self is of specified type and croaks if not.

=cut

sub requiredType {
	my $self = shift;
	my $type = shift;

	if ( !$type ) {
		croak "requiredType called with type";
	}

	if ( ref $self ne $type ) {
		croak "Wrong type: " . ref $self;
	}

}

=head2 $self->requiredFeatures ($hashref, 'a', b');

Feature is a key of a hashref, either the object itself or another hashref
object.

Croaks if a or b are not present. If hashref is omitted, checks in $self.

Variation:
	$self->requiredFeatures ('a', b');

=cut

sub requiredFeatures {
	my $self = shift;    #hashref
	#my $args;            #string or hashref
	if (ref $_[0] eq 'HASH') {
		my $args = shift;
		foreach my $key (@_) {
			if ( !$args->{$key} ) {
				croak "Feature $key missing";
			}
		}
	} else {
		foreach my $key (@_) {
			if ( !$self->{$key} ) {
				croak "Feature $key missing";
			}
		}

	}
}

sub argumentExists {
	my $self = shift;
	my $arg  = shift;

	if ( !$arg ) {
		croak "Argument missing!";
	}
}

sub _hashref {
	my %params = @_;
	return \%params;
}

1;    #HTTP::OAI::DataProvider::Engine
