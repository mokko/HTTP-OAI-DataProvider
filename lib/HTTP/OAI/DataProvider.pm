package HTTP::OAI::DataProvider;

# ABSTRACT: A simple OAI data provider

use strict;
use warnings;
use Carp qw/croak carp/;
use Encode qw(encode_utf8);
use XML::SAX::Writer;
use URI;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

use HTTP::OAI;
use HTTP::OAI::Repository 'validate_request';
use HTTP::OAI::DataProvider::Engine;
use HTTP::OAI::DataProvider::SetLibrary;
use HTTP::OAI::DataProvider::Common qw/Debug Warning say/;

=head1 SYNOPSIS

	#(1) Init
	use HTTP::OAI::DataProvider;
	my $provider = HTTP::OAI::DataProvider->new(%options);
	
	#(2) Verbs: GetRecord, Identify ...
	my $response=$provider->$verb(%params);
	my $xml=$provider->asString($response);

	my $xml=$provider->asString($response);
	#$response is a HTTP::OAI::Response object (verbs or error)

	#(3) NEW ERROR HANDLING
	my $response=$provider->addError(code=>'badArgument');

	if (!$provider->validateRequest (%params));
		my $response=$provider->OAIerrors;
	}

	#elsewhere
	if ($provider->error) { 	
		my $response=$provider->OAIerrors;
		my $xml=$provider->asString($response);
		$provider->resetErrorStack;
	}

=head1 DESCRIPTION

This package implements an OAI data provider according to 
L<http://www.openarchives.org/OAI/openarchivesprotocol.html>

The provider is database and metadata format agnostic. It comes with simple 
example implementations that should work out of the box, including an SQLite 
backend (DP::Engine::SQLite), a metadata format (DP::Mapping::MPX), web 
interface (bin/webapp.pl) and a command line interface (bin/dp.pl).

I try to avoid too obscure dependencies. 

Starting from version 0.07, the user-facing interface of this module should be 
mostly stable.

Note: I use 'DP::' as an abbreviation of 'HTTP::OAI::DataProvider::' 
thoughout the documentation.

=method my $provider->new ($options);

Initialize the HTTP::OAI::DataProvider object with the options of your choice.

On failure return nothing. 

=head3 Identify Parameters 

expects a hashref with key value pairs inside all of which are required:

	identify => {
		adminEmail     => 'mauricemengel@gmail.com',
		baseURL        => 'http://localhost:3000/oai',
		deletedRecord  => 'transient',
		repositoryName => 'test config OAI Data Provider',
	},

See OAI specification (Identify) for available options and other details.

=head3 Engine Parameters

engine->{engine} specifies the engine you use. Other parameters depend on the
engine you use. All engine parameters are handed down to the engine you use. 

	engine => {
		engine    => 'HTTP::OAI::DataProvider::Engine::SQLite',
		moreParameters => 'see your engine for more info on those params', 
	},

=head3 Message Parameters 

	debug   => sub { my $msg = shift; print "<<$msg\n" if $msg; },
	warning => sub { my $msg = shift; warn ">>$msg"    if $msg; },

=head3 Metadata Format Parameters 

	globalFormats => {
		mpx => {
			ns_uri => "http://www.mpx.org/mpx",
			ns_schema =>
			  "http://github.com/mokko/MPX/raw/master/latest/mpx.xsd",
		},
		oai_dc => {
			ns_uri    => "http://www.openarchives.org/OAI/2.0/oai_dc/",
			ns_schema => "http://www.openarchives.org/OAI/2.0/oai_dc.xsd",
		},
	},

=head3 Set Parameters 

	setLibrary => {
		'78' => {
			    'setName' => 'Schellackplatten aus dem Phonogramm-Archiv'
		},
		'MIMO' =>
		  { 'setName' => 'Musical Instruments selected for MIMO project' },
		'test' => {
			'setName' => 'testing setSpecs - might not work without this one',
		},
	},

=head3 Other Parameters (Optional)

	xslt => '/oai2.xsl',

	Adds path to HTTP::OAI::Repsonse objects to modify output in browser.
	
	requestURL => 'http://bla.url'
	
	Overwrite normal requestURL, e.g. when using a reverse proxy etc.
	Note that requestURL specified during new is only the http://domain.com:port
	part (without ? followed by GET params), but that HTTP::OAI treats the
	complete URL as requestURL

=cut

subtype 'identifyType', as 'HashRef', where {
	     defined $_->{adminEmail}
	  && defined $_->{baseURL}
	  && defined $_->{deletedRecord}
	  && defined $_->{repositoryName}
	  && URI->new( $_->{baseURL} )->scheme;
};

subtype 'globalFormatsType', as 'HashRef', where {
	foreach my $prefix ( keys %{$_} ) {
		return if ( !_uriTest( $_->{$prefix} ) );
	}
	return 1;    #success
};

#subtype 'Uri' already declared in Engine

#required
has 'engine' => ( isa => 'HashRef', is => 'ro', required => 1 );
has 'globalFormats' => (
	isa      => 'globalFormatsType',
	is       => 'ro',
	required => 1
);
has 'identify'   => ( isa => 'identifyType', is => 'ro', required => 1 );
has 'setLibrary' => ( isa => 'HashRef',      is => 'ro', required => 1 );

#optional
has 'debug'      => ( isa => 'CodeRef', is => 'ro', required => 0 );
has 'requestURL' => ( isa => 'Uri',     is => 'rw', required => 0 );
has 'warning'    => ( isa => 'CodeRef', is => 'ro', required => 0 );
has 'xslt'       => ( isa => 'Str',     is => 'ro', required => 0 );
has 'OAIerrors'  => (
	is       => 'rw',
	required => 0,
	init_arg => undef,
	isa      => 'HTTP::OAI::Response',
	default  => sub { HTTP::OAI::Response->new }

	  #	default  => sub {
	  #		my $self = shift;
	  #		my $response =
	  #		  HTTP::OAI::Response->new( requestURL => $self->requestURL );
	  #		return $response;
	  #	}
);

sub BUILD {
	my $self = shift or die "Need myself!";

	Debug( $self->debug )     if ( $self->debug );
	Warning( $self->warning ) if ( $self->warning );

	$self->{Engine} = new HTTP::OAI::DataProvider::Engine( %{ $self->engine } );
}

=method my $result=$provider->GetRecord(%params);

Arguments
=for :list
* identifier (required)
* metadataPrefix (required)

Errors
=for :list
* badArgument
* cannotDisseminateFormat
* idDoesNotExist

=cut

sub GetRecord {
	my $self   = shift;
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error

	$self->resetErrorStack;    #not sure if this should be here

	$params{verb} = 'GetRecord';
	$self->validateRequest(%params) or return $self->OAIerrors;

	my $engine        = $self->{Engine};
	my $globalFormats = $self->{globalFormats};

	# Error handling
	my $header = $engine->findByIdentifier( $params{identifier} );
	if ( !$header ) {
		$self->addError( code => 'idDoesNotExist' );
	}

	$self->checkFormatSupported( $params{metadataPrefix} );

	return $self->OAIerrors if ( $self->OAIerrors->errors );    ####

	# Metadata handling
	return $engine->query( \%params );
}

=method my $response=$provider->Identify([%params]);

Arguments: none

Errors: badArgument

The information for the identify response is assembled from two sources: from
configuration during new and from inspection of the system (earlierstDate, 
granularity).

=cut

sub Identify {
	my $self = shift or die "Need myself";
	my %params = $self->_verb( verb => 'ListMetadataFormats', @_ );
	return $self->OAIerrors if ( $self->error );
	my $identify = $self->identify;

	#Debug "Enter Identify";
	# Metadata munging
	my $response = new HTTP::OAI::Identify(
		adminEmail    => $identify->{adminEmail},
		baseURL       => $identify->{baseURL},
		deletedRecord => $identify->{deletedRecord},

		#probably a demeter problem
		earliestDatestamp => $self->{Engine}->earliestDate(),
		granularity       => $self->{Engine}->granularity(),
		repositoryName    => $identify->{repositoryName},
		requestURL        => $identify->{requestURL},
	) or return "Cannot create new HTTP::OAI::Identify";

	return $response;    #success
}

=method ListMetadataFormats (%params);

"This verb is used to retrieve the metadata formats available from a
repository. An optional argument restricts the request to the formats available
for a specific item." (the spec)

HTTP::OAI::DataProvider only knows global metadata formats, i.e. it assumes
that every record is available in every format supported by the repository.

ARGUMENTS

=for :list
* identifier (optional)

ERRORS

=for :list
* badArgument - in validate_request()
* idDoesNotExist - here
* noMetadataFormats - here

=cut

=method 

	my %params=$self->_verb(verb=>'ListMetadataFormats', %params);
	return $self->OAIerrors if ( $self->error );     

=cut

sub _verb {
	my $self = shift or die "Need myself";

	#dont croak here, prefer propper OAI error
	my %params = @_ or ();

	$self->resetErrorStack;    #not sure if this should be here
	$self->validateRequest(%params);
	return %params;

}

sub ListMetadataFormats {
	my $self = shift or die "Need myself";
	my %params = $self->_verb( verb => 'ListMetadataFormats', @_ );
	return $self->OAIerrors if ( $self->error );

	my $engine = $self->{Engine};

	#only if there is actually an identifier
	if ( $params{identifier} ) {
		my $header = $engine->findByIdentifier( $params{identifier} );
		if ( !$header ) {
			$self->addError( code => 'idDoesNotExist' );
		}
	}

	#Metadata Handling
	my $list = HTTP::OAI::ListMetadataFormats->new();
	foreach my $prefix ( keys %{ $self->{globalFormats} } ) {

		#print "prefix:$prefix\n";
		my $format = new HTTP::OAI::MetadataFormat;
		$format->metadataPrefix($prefix);
		$format->schema( $self->{globalFormats}{$prefix}{ns_schema} );
		$format->metadataNamespace( $self->{globalFormats}{$prefix}{ns_uri} );
		$list->metadataFormat($format);
	}

	#check if noMetadataFormats
	if ( $list->metadataFormat() == 0 ) {
		$self->addError( code => 'noMetadataFormats' );
	}

	if ( $self->error ) {
		return $self->OAIerrors;
	}
	return $list;    #success
}

=method my $response=$provider->ListIdentifiers (%params);

ARGUMENTS

=for :list
* from (optional, UTCdatetime value)
* until (optional, UTCdatetime value)
* metadataPrefix (required)
* set (optional)
* resumptionToken (exclusive) 

ERRORS

=for :list
* badArgument
* badResumptionToken
* cannotDisseminateFormat
* noRecordsMatch
* noSetHierarchy

NOTE 
Depending on the repository's support for deletions, a returned header may have
a status attribute of "deleted" if a record matching the arguments specified in
the request has been deleted.

LIMITATIONS
By making the metadataPrefix required, the specification suggests that
ListIdentifiers returns different sets of headers depending on which
metadataPrefix is chose. HTTP:OAI::DataProvider assumes, however, that there 
are only global metadata formats, so it will return the same set for all 
supported metadataFormats.

TODO: Hierarchical sets

=cut

sub ListIdentifiers {
	my $self = shift or croak "Need myself!";
	my %params = $self->_verb( verb => 'ListIdentifiers', @_ );
	return $self->OAIerrors if ( $self->error );

	my $engine = $self->{Engine}
	  or croak "Internal error: Data store missing!";

	if ( $params{resumptionToken} ) {

		#chunk is response object here!
		my $chunk = $engine->chunkExists(%params);

		if ($chunk) {
			return $self->asString($chunk);    #success
		}

		return $self->addError( code => 'badResumptionToken' );
	}

	#reach here if no resumption token
	$self->checkFormatSupported( $params{metadataPrefix} );
	if ( $params{Set} ) {

		#sets defined in data store
		my @used_sets = $engine->listSets;

		#query contains sets, but data has no set defined
		if ( !@used_sets ) {
			$self->addError( code => 'noRecordsMatch' );
		}
	}

	#Metadata handling: query returns response
	#always only the first chunk
	my $response = $engine->query( \%params );    #todo!

	if ( !$response ) {
		$self->addError( code => 'noRecordsMatch' );
	}

	#todo: check if at least one record. Where?
	return $self->OAIerrors if ( $self->error );
	return $response;
}

=method my $response=$provider->ListRecords(%params);

returns multiple items (headers plus records) at once. In its capacity to
return multiple objects it is similar to the other list verbs
(ListIdentifiers). ListRecord also has the same arguments as ListIdentifier.
In its capacity to return full records (incl. header), ListRecords is similar
to GetRecord.

ARGUMENTS

=for :list
* from (optional, UTCdatetime value) 
* until (optional, UTCdatetime value) 
* metadataPrefix (required unless resumptionToken)
* set (optional)
* resumptionToken (exclusive)

ERRORS

=for :list
* badArgument
* badResumptionToken 
* cannotDisseminateFormat
* noRecordsMatch
* noSetHierarchy - TODO

=cut

sub ListRecords {
	my $self = shift;
	my %params = $self->_verb( verb => 'ListRecords', @_ );
	return $self->OAIerrors if ( $self->error );
	my $engine = $self->{Engine};

	#Warning 'Enter ListRecords (prefix:' . $params->{metadataPrefix};

	#Debug 'from:' . $params->{from}   if $params->{from};
	#Debug 'until:' . $params->{until} if $params->{until};
	#Debug 'set:' . $params->{set}     if $params->{set};
	#Debug 'resumption:' . $params->{resumptionToken}
	#  if $params->{resumptionToken};

	# Error handling

	if ( $params{resumptionToken} ) {
		my $chunk = $engine->chunkExists(%params);
		return $chunk if ($chunk);
		return $self->addError( code => 'badResumptionToken' );
	}

	$self->checkFormatSupported( $params{metadataPrefix} );

	return $self->OAIerrors if ( $self->error );

	# Metadata handling

	my $response = $engine->query( \%params );
	return $self->addError( code => 'noRecordsMatch' ) if ( !$response );
	return $response;
}

=method my $response=$provider->ListSets(%params);

ARGUMENTS

=for :list
* resumptionToken (optional)

ERRORS

=for :list
* badArgument 
* badResumptionToken  
* noSetHierarchy 

=cut

sub ListSets {
	my $self   = shift           or croak "Provider missing!";
	my $engine = $self->{Engine} or croak "Engine missing!";
	my %params = $self->_verb( verb => 'ListSets', @_ );
	return $self->OAIerrors if ( $self->error );

	#Debug "Enter ListSets $self\n";

	#resumptionTokens not supported/TODO
	if ( $params{resumptionToken} ) {
		return $self->addError(
			code    => 'badResumptionToken',
			message => 'resumption token not yet supported with listsets'
		);
	}

	# Get the setSpecs from engine/store
	# TODO:test for noSetHierarchy has to be in SetLibrary
	my @used_sets = $engine->listSets;

	#if none then noSetHierarchy (untested)
	if ( !@used_sets ) {
		return $self->addError( code => 'noSetHierarchy' );
	}

	my $listSets = $self->_processSetLibrary();

	my $library = HTTP::OAI::DataProvider::SetLibrary->new;
	$library->addListSets($listSets)
	  or die "Error: some error occured in library->addListSet";

	if ($library) {
		$listSets = $library->expand(@used_sets);
	}
	else {

		Warning "setLibrary cannot be loaded, proceed without setNames and "
		  . "setDescriptions";

		foreach (@used_sets) {
			my $s = HTTP::OAI::Set->new;
			$s->setSpec($_);
			$listSets->set($s);
		}
	}
	return $listSets;
}

=method checkFormatSupported ($prefixWanted);

Expects a prefix for a metadataPrefix (as scalar). If it can't be disseminated 
an error is raised in $self->OAIerrors

	$self->checkFormatSupported( $params->{metadataPrefix} )
	if ($self->OAIerror->errors) { 		#errors is kind a like is_error
		#do something
	}

=cut

sub checkFormatSupported {
	my $self         = shift or carp "Need self!";
	my $prefixWanted = shift or carp "Need something to test for";
	if ( !$self->{globalFormats}{$prefixWanted} ) {
		$self->addError( code => 'cannotDisseminateFormat' );
	}
}

=method my $xml=$self->asString($response);

Expects a HTTP::OAI::Response object and returns it as xml string. It applies
$self->{xslt} if set and also applies a current requestURL.

=cut

sub asString {
	my $self = shift or croak "Need myself";
	my $response = shift
	  or croak "No response";    #a HTTP::OAI::Response object
	Debug "$response: " . $response;
	$self->_init_xslt($response);
	$response = $self->_transferRURL($response);

	my $xml;
	$response->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
	$response->generate;

	return encode_utf8($xml);

#as per https://groups.google.com/forum/?fromgroups#!topic/psgi-plack/J0IiUanfgeU
}

#
#
#

=method $obj= $self->_transferRURL($response)

Transfers the requestURL from the provider (where it might have changed in the
meantime) to the response.

N.B. Currently it preserves the params of the response's RURL. I am not sure 
that there ever are some.

=cut

sub _transferRURL {
	my $self = shift or croak "Need myself";
	my $response = shift
	  or croak "Need response";    #e.g. HTTP::OAI::ListRecord

	$response->requestURL( $self->requestURL );
	return $response;

}

=method $obj= $self->_init_xslt($obj)

For an HTTP::OAI::Response object ($obj), sets the stylesheet to the value
specified during init. This assume that there is only one stylesheet.

This may be a bad name, since not specific enough. This xslt is responsible
for a nicer look and added on the top of reponse headers.

=cut

sub _init_xslt {
	my $self = shift;
	my $obj = shift or return;    #e.g. HTTP::OAI::ListRecord

	#Debug "Enter _init_xslt obj:$obj"; #beautify
	if ( $self->xslt ) {
		$obj->xslt( $self->xslt ) or croak "problems with xslt!";
	}
}

=method $self->addError(code=>$code, message=>$message);

Expected is an error code and optionally an error message. If not specified, 
message will use default message for that error code. Returns a 
HTTP::OAI::Response object with the error stack. Croaks on failure.

TODO: Theoretically, I need a way to add multiple errors at once:

$self->addError([(code=>$code, message=>$message), (code=>$code, message=>$message)]);

=cut

sub addError {
	my $self = shift or croak "Need myself";
	my %args = @_;
	die "Need error code!" if ( !$args{code} );

	$self->OAIerrors->errors( HTTP::OAI::Error->new(%args) );
	return $self->OAIerrors;

}

=method $self->error

Have errors occured? Returns number of errors that have been added to error 
stack so far or else false.

=cut

sub error {
	my $self = shift or croak "Need myself";
	return $self->OAIerrors->errors;
}

=method $provider->resetErrorStack;

Creates a new empty HTTP::OAI::Response for OAIerrors. 

I wonder if this should be called before every verb. Then I probably don't
need to call it from the outside at all.

=cut

sub resetErrorStack {
	my $self = shift or croak "Need myself!";
	$self->OAIerrors( HTTP::OAI::Response->new );
}

=method $self->validateRequest(%params) or return $self->OAIerrors;

My validateRequest returns 1 on success (i.e. no validation error).
=cut

sub validateRequest {
	my $self = shift or croak "Need myself!";
	my %params = @_ or ();    #dont croak here, prefer propper OAI error
	foreach my $err ( validate_request(%params) ) {
		$self->OAIerrors->errors($err);    #adds to error stack manually
		 #$self->addError(code=>$err->code, message=>$err->message);    #adds to error stack manually
	}

	#avoid HTTP::OAI::Response->is_error since it makes trouble
	if ( $self->error ) {
		Debug "validateRequest: found error";
		return;    # error = request NOT valid
	}
	Debug "validateRequest: found NO error";
	return 1;    #success = request is valid
}

sub _uriTest {
	my $format = shift or croak "Need format!";
	my @keys = qw (ns_uri ns_schema);

	foreach my $key (@keys) {
		return if ( !$format->{$key} );
		my $uri = URI->new( $format->{$key} );
		if ( !$uri->scheme ) {

			#print "ns_uri is not URI\n";
			return;
		}
	}
	return 1;    #exists and is uri
}

sub _processSetLibrary {
	my $self = shift or croak "Need myself!";

	#debug "Enter process_setLibrary";
	my $setLibrary = $self->{setLibrary};

	if ( %{$setLibrary} ) {
		my $listSets = new HTTP::OAI::ListSets;

		foreach my $setSpec ( keys %{$setLibrary} ) {

			my $s = new HTTP::OAI::Set;
			$s->setSpec($setSpec);
			$s->setName( $setLibrary->{$setSpec}->{setName} );

			#print "setSpec: $setSpec\n";
			#print "setName: " . $setLibrary->{$setSpec}->{setName}."\n";

			if ( $setLibrary->{$setSpec}->{setDescription} ) {

				foreach
				  my $desc ( @{ $setLibrary->{$setSpec}->{setDescription} } )
				{

					#not sure if the if is necessary, but maybe there cd be an
					#empty array element. Who knows?

					my $dom = XML::LibXML->load_xml( string => $desc );
					$s->setDescription(
						new HTTP::OAI::Metadata( dom => $dom ) );
				}
			}
			$listSets->set($s);
		}
		return $listSets;
	}
}

=head1 SEE ALSO

=over 1

=item L<http://www.openarchives.org/OAI/openarchivesprotocol.html>

=item Tim Brody's L<HTTP::OAI>

=item Jeff Young's (OCLC) OAICAT (java) at 
L<http://www.oclc.org/research/activities/oaicat/>

=back

=cut

__PACKAGE__->meta->make_immutable;
1;
