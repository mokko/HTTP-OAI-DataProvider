package HTTP::OAI::DataProvider::Engine;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);    #to generate unique tokens

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

sub _hashref {
	my %params = @_;
	return \%params;
}

=head2 $engine->import ($source, 'a','b');

Expects a hashref and a list of keys. Copies key value pairs mentioned in the
list (not clones, but references) to the object. In this case engine.

In usage example above,
	$engine->{a}=$source->{a}

Returns 0 for success and 1 or higher for error.

If $source->{a} doesn't exist, $engine->{a} will not be created.

=cut

sub import {
	my $self   = shift;
	my $source = shift;
	my $error=0;

	if (ref $source ne 'HASH') {
		return $error; #source not a hashref
	}

	foreach my $var (@_) {
		if ( $self->$var ) {
			$self->$var = $source->$var;
		} else {
			$error++;
		}
	}
	return $error;
}

1;       #HTTP::OAI::DataProvider::Engine
