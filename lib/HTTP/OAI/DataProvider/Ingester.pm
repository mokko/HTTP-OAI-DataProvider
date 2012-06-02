package HTTP::OAI::DataProvider::Ingester;
#ABSTRACT: Get data from XML file into the DB 
use strict;
use warnings;
use Moose;
use Carp qw(carp croak confess);
use HTTP::OAI::DataProvider::Common qw(Debug Warning);

use XML::LibXML;

has 'engine'       => ( isa => 'Str', is => 'ro', required => 1 );
has 'nativePrefix' => ( isa => 'Str', is => 'ro', required => 1 );
has 'nativeURI'    => ( isa => 'Str', is => 'ro', required => 1 );
has 'dbfile'       => ( isa => 'Str', is => 'ro', required => 1 );

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

Get stuff into the database by parsing an XML file. 
	
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
	$self->_initDB() or confess "Cant init database";

}

=method $ingester->digest(source=>$file,mapping=>$mapping);

Expects the location of an XML file and a mapping, i.e. a callback to code 
which parses XML into HTTP::OAI::Records. 

The digest method calls $engine->storeRecord($record).

=cut

sub digest {
	my $self = shift;
	my %args = @_;
	
	return if ( !$self->valFileExists( $args{source} ) );
	return if ( !$self->valIfExists( $args{mapping} ) );

	my $mapping = $args{mapping};
	my $doc = $self->loadXML( $args{source} );
	return if ( !$self->valIfExists($doc) );

	no strict "refs";
	while ( my $record = $self->$mapping($doc) ) {
			$self->storeRecord($record) or croak "storeRecord problem";
	}
	return 1; #success
}

#
# NOT IF THIS METHOD SHOULD BE SOMEWHERE ELSE. I HAVE THE IMPRESSION I NEED 
# registerNS somewhere else
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

=method my $doc=$self->loadXML($xmlFile);

Expects a path to an XML file, registers native namespace and returns a
XML::LibXML::Document.

=cut

sub loadXML {
	my $self     = shift or carp "Need myself";
	my $location = shift or return;

	#Debug "Enter _loadXML ($location)";

	my $doc = XML::LibXML->load_xml( location => $location )
	  or croak "Could not load " . $location;

	$doc = registerNS( $self, $doc );

	return $doc;
}
#doesn't work if immutabale; i am not exactly sure why
#__PACKAGE__->meta->make_immutable;
1;
