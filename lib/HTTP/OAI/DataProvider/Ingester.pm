package HTTP::OAI::DataProvider::Ingester;
use strict;
use warnings;
use Moose;
use Carp qw(carp croak confess);

#use Module::Loader;
use XML::LibXML;
#use HTTP::OAI::DataProvider::Common qw(hashRef2hash);

has 'engine'     => ( isa => 'Str',     is => 'ro', required => 1 );
has 'nativePrefix' => ( isa => 'Str', is => 'ro', required => 1 );
has 'nativeURI'    => ( isa => 'Str', is => 'ro', required => 1 );
has 'dbfile'    => ( isa => 'Str', is => 'ro', required => 1 );

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::Ingester;
	my $mouth=new HTTP::OAI::DataProvider::Ingester (
		engine=>'OAI::DP::SQLite', 
		engineOpts=$hashRef,
	);
	#ingester internally calls new OAI::DP::SQlite (%dbOpts);
	$ingester->digest($file,$mapping);
	#internally calls OAI::DP::SQLite->storeRecord ($OAIrecord);

=head1 DESCRIPTION

I wonder if it makes sense to separate the ingest process which imports data
into the database from the rest of the database stuff that gets data out of
database.

At the very least it should be a playing field to test a rudimentary database
abstraction layer.

Ideally, I have a part that is specific for SQLite and one part that works
generally. The current implementation (as part of the SQLite pacakge) 
consists

SQLite->digest_single ($file,&$mapping);
    loads XML file specified in $file and hands it to the code specified in
    $mapping. Expects a complete HTTP::OAI::Record back from $mapping.
    calls _storeRecord($record)
    This part is generic. It is not database specific and it is not dependent
    on the metadata format. (The part that is metadataFormat specific is 
    already separated out as mapping.)
: SQLite->_storeRecord
	First checks if record with that OAI id already exists and what its 
	timestamp are (first SQL).
	Then either  
	a) do nothing 
	b) update db record (second SQL)
	c) insert db record (third SQL)
	
	So we have three steps:
	a) a timestamp comparison which triggers appropriate follow-up action 
	   (involving first SQL)
	b) insertSQL
	c) updateSQL 
	
	This part does not depend on metadataFormat, but on the database
	
=head1 COMMUNICATION BETWEEN PACKAGES

I want a solution where I have a clearly defined interface to write multiple
DB backends. My current implementation of SQLite, for example, uses a very
simple and not very efficient database layout, where a lot of perKor 
information exists multiple times.

Or somebody else might want to use a different database altogether.

Imagine we had such an alternative database implementation and it would be
called OAI::DP::MySql. How would the dataProvider know which package to load?

Obviously, we have to have a new config value which tells him.

But OAI::DP::MySQL might also come with it own configuration

new OAI::DP::SQLite(%opts1);
new OAI::DP::MySQL(%opts2);

OAI::DP::Database (generic = not db-specific);
-defines a role/interface for the db-specific implementations


Which possibilities do I have?

a) callback: I have used this to separate out MPX-specific stuff which goes into
	the Salsa package. As a result OAI::DataProvider is independent of 
	metadataFormat.  
b) I have a separate package X which inherits from DataProvider

	package X
	base OAI::DataProvider
	use OAI::DataProvider::MySQL;



c) I could tell either DataProvider or its engine which 

=cut

sub BUILD {
	my $self = shift or croak "Need myself";
	my $engine = $self->engine;

	#dynamically consume a role and inherit from it
	with $engine;

	#$self->{transformer} = new HTTP::OAI::DataProvider::Transformer(
	#	nativePrefix => $self->nativePrefix,
	#	locateXSL    => $self->locateXSL,
	#);
	$self->initDB() or croak "Cant init database";

}

=method $ingester->digest($file,$mapping);

Expects the location of an XML file and a mapping, i.e. a callback to code 
which parses XML into HTTP::OAI::Records. 

The digest method calls $engine->storeRecord($record).

=cut

sub digest {
	my $self = shift;
	my %args = @_;

	if ( valFileExists( $args{source} ) ) {
		return;    #failure
	}
	if ( !$args{source} ) {
		$self->{errorMessage} = 'no source';
		return;
	}

	if ( !-e $args{source} ) {
		$self->{errorMessage} = 'Source file not found';
		return;
	}

	if ( !$args{mapping} ) {
		croak "No mapping callback specified";
	}

	my $doc = $self->loadXML( $args{source} );

	croak "No document" if ( !$doc );

	my $mapping = $args{mapping};
	no strict "refs";
	while ( my $record = $self->$mapping($doc) ) {
		$self->storeRecord($record);
	}
}

#
# NOT SURE ABOUT THIS
#

sub registerNS {
	my $self = shift;
	my $doc  = shift;

	#Debug 'Enter _registerNS';

	if ( $self->{nativePrefix} ) {
		if ( !$self->{nativeURI} ) {
			croak "ns_prefix specified, but ns_uri missing";
		}

		#Debug 'ns: ' . $self->{nativePrefix} . ':' . $self->{nativeURI};

		$doc = XML::LibXML::XPathContext->new($doc);
		$doc->registerNs( $self->{nativePrefix}, $self->{nativeURI} );
	}
	return $doc;
}

=method my $doc=$self->_loadXML($xmlFile);

Expects a path to an XML file, registers native namespace and returns a
XML::LibXML::Document.

=cut

sub loadXML {
	my $self     = shift or carp "Need myself";
	my $location = shift or return;

	#Debug "Enter _loadXML ($location)";

	my $doc = XML::LibXML->load_xml( location => $location )
	  or croak "Could not load " . $location;

	$doc = _registerNS( $self, $doc );

	return $doc;
}

1;
