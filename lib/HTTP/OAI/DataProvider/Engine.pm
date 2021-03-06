package HTTP::OAI::DataProvider::Engine;
{
  $HTTP::OAI::DataProvider::Engine::VERSION = '0.009';
}
use strict;
use warnings;

# ABSTRACT: interface between database and data provider
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Scalar::Util qw(looks_like_number);
use Time::HiRes qw(gettimeofday);    #to generate unique tokens
use Carp qw(carp croak);
use URI;
use HTTP::OAI::DataProvider::Common qw/Debug say Warning/;
use HTTP::OAI::DataProvider::ChunkCache;
use HTTP::OAI::DataProvider::Transformer;

subtype 'nativeFormatType', as 'HashRef', where {
	return if scalar keys %{$_} != 1;    #exactly one key
	my $prefix = ( keys %{$_} )[0];
	return if ( !$_->{$prefix} );        #value has to be defined
	my $ns_uri = $_->{$prefix};
	return if ( !URI->new($ns_uri)->scheme );    #value has to be URI
	return 1;                                    #success
};

subtype 'chunkCacheType', as 'HashRef', where {
	my @list = qw (maxChunks recordsPerChunk);
	foreach my $item (@list) {
		my $it=$_->{$item};
		return unless ( $it && looks_like_number($it) && $it > 0 );
	}
	return 1;                                    #success
};

subtype 'Uri', as 'Str', where { URI->new($_)->scheme; };

has 'chunkCache'   => ( isa => 'chunkCacheType',   is => 'ro', required => 1 );
has 'dbfile'       => ( isa => 'Str',              is => 'ro', required => 1 );
has 'engine'       => ( isa => 'Str',              is => 'ro', required => 1 );
has 'locateXSL'    => ( isa => 'CodeRef',          is => 'ro', required => 1 );
has 'nativeFormat' => ( isa => 'nativeFormatType', is => 'ro', required => 1 );
has 'requestURL'   => ( isa => 'Uri',              is => 'rw', required => 0 );

#N.B. $self->ChunkCache is HTTP::OAI::DataProvider::ChunkCache object.


sub nativePrefix {
	my $self = shift or confess "Need myself!";
	my $nativePrefix = ( keys %{ $self->nativeFormat } )[0];

	confess "something's wrong with nativePrefix" if ( !$nativePrefix );
	return $nativePrefix;
}

sub BUILD {
	my $self = shift or croak "Need myself";

	#dynamically consume a role and inherit from it

	$self->{transformer} = new HTTP::OAI::DataProvider::Transformer(
		nativePrefix => $self->nativePrefix,
		locateXSL    => $self->locateXSL,
	);
	with $self->engine;

	$self->init();
}


sub query {
	my $self   = shift or croak "Need myself!";
	my $params = shift or croak "Need params!";

	my $first = $self->planChunking($params);

	#if there are no results there is no first chunk
	if ( !$first ) {
		$self->{error} = 'query: no results (no chunk)!';
		return;
	}

	my $response = $self->queryChunk( $first, $params );

	#todo: we still have to test if result has any result at all
	return $response;
}


sub chunkExists {
	my $self            = shift or croak "Need myself!";
	my %params          = @_;
	my $resumptionToken = $params{resumptionToken} or return;

	my $chunkCache = $self->{ChunkCache};

	#Debug "->>>>>>>--Query chunkCache for " . $resumptionToken;

	my $chunkDesc = $chunkCache->get($resumptionToken) or return;

	#returns a chunk
	return $self->queryChunk( $chunkDesc, \%params );
}


###
### OLD STUFF - Todo: check if still needed!
###


sub mkToken {
	my ( $sec, $msec ) = gettimeofday;
	return time . $msec;
}

#doesn't work if it is immutable
#__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

HTTP::OAI::DataProvider::Engine - interface between database and data provider

=head1 VERSION

version 0.009

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::Engine;
	my $engine=new HTTP::OAI::DataProvider::Engine (
		engine=>'DataProvider::SQLite',
		engineOpts=>$hashRef,
	);
	#internally calls $engine->init();

	#main query
	$result=$provider->query ($params);

	#other queries
	$header=$engine->findByIdentifier($identifier);

	#chunking
	my $firstChunkDescription=$self->planChunking($params);
	
	#used in Identify
	$engine->earliestDate();
	$engine->granularity();

	#used in ingestion process
	#has its own wrapper
	$engine->storeRecord

=head2 $result=$provider->query ($params);

Expects OAI parameters as hashref (TODO: hash). query 
a) plans the chunking, 
b) saves the chunks in chunk cache and 
c) returns the first chunk as
	HTTP::OAI::DataProvider::Result 
   reflecting data from database

Gets called from GetRecord, ListRecords, ListIdentifiers. Possible parameters
are metadataPrefix, from, until and Set. (Queries including a resumptionToken
should not get here.)

TODO: What to do on failure? Should return nothing and set $self->error 
internally

=head1 DESCRIPTION

Engine is the generic part for getting data of out the database (querying). 
Engine loads the specific database engine, e.g. DP::Engine::SQLite. (Actually,
consumes the engine as a role and hence inherits methods from it, but I am not
sure that this distinction is necessary in this place). 

Engine is analogous to the DP::Ingester package which provides a similar 
service for getting data into the database.

This class is generic in the sense that it doesn't know about   
 a) the metadataFormat AND
 b) the concrete database.

=head2 CLASS LAYOUT

HTTP::OAI::DataProvider (object) creates
  DP::Engine (class) consumes
    DP::Engine::SQLite (role) consumes
      DP::Engine::Interface (role)
      	is more than just interface, also includes some general methods

analogous for Ingester:
DP::Ingester (class) consumes
  DP::Engine::SQLite (role) consumes
    DP::Engine::Interface (role)

=head1 METHODS

=head2 my $chunk=$self->chunkExists (%params);

returns a chunk (not a chunk description) for a specified resumptionToken or 
nothing (no chunk exists for this token).

Expects a hashref with a resumptionToken (resumptionToken=>$token). On failure 
(if resumptionToken is not known to chunk cache), it returns nothing.

	my $chunk=$self->chunkExists (%params);
	if (!$chunk) {
		return new HTTP::OAI::Error (code=>'badResumptionToken');
	}

	#or:
 	my $chunk=$engine->chunkExists(resumptionToken=>$resumptionToken) or return;

=head1 MEMO TO MYSELF

-A child class inherits methods from the parent.
-Conversely, a parent class gives its methods to a child class. 
-The child declares its parent class (who their parent is).

-A role (definition) gives its methods to the consumer. 
-Conversely, the consumer inherits methods from the role. 
-The consumer declares its role using the 'with' keyword.

Engine could be role. SQLite could consumer or vice versa.

What I really want to do is to dynamically load a module, either as 
role or as a module to do this:
	package Engine {
		use Moose;
		with $someModule;
		my $engine= new $someModule (%opts);
		$engine->method();
	}

	Engine inherits methods from SQLite.
	Database defines interface for SQLite.

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

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
