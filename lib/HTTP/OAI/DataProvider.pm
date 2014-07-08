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
use HTTP::OAI::DataProvider::Engine;   #subtype 'Uri' already declared in Engine
use HTTP::OAI::DataProvider::SetLibrary;
use HTTP::OAI::DataProvider::Common qw/Debug Warning say/;

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider;
	my $provider = HTTP::OAI::DataProvider->new(%options) or die "Can't init";
	my $response=$provider->verb(%params); 	#a HTTP::OAI::Response object (verbs or error)

	if ($provider->error) { 	
		my $response=$provider->OAIerrors;
		my $xml=$provider->asString($response);
		$provider->resetErrorStack;
	}
	my $xml=$provider->asString($response);

	#param validation is done internally now, but you could still do it on your end
	if (!$provider->validateRequest (%params));
		my $response=$provider->OAIerrors;
	}


=head1 DESCRIPTION

This package implements an OAI data provider according to 
L<http://www.openarchives.org/OAI/openarchivesprotocol.html>

The provider is database and metadata format agnostic. It comes with simple 
example implementations that should work out of the box, including an SQLite 
backend (DP::Engine::SQLite), a metadata format (DP::Mapping::MPX), web 
interface (bin/webapp.pl) and a command line interface (bin/dp.pl).

=method my $provider->new ($options) or die "Can't init";

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

=cut

subtype 'identifyType', as 'HashRef', where {
	     defined $_->{adminEmail}
	  && defined $_->{baseURL}
	  && defined $_->{deletedRecord}
	  && defined $_->{repositoryName}
	  && URI->new( $_->{baseURL} )->scheme;
};

has 'identify' => ( isa => 'identifyType', is => 'ro', required => 1 );

=head3 Engine Parameters

engine->{engine} specifies the engine you use. Other parameters depend on the
engine you use. All engine parameters are handed down to the engine you use. 

	engine => {
		engine    => 'HTTP::OAI::DataProvider::Engine::SQLite',
		moreParameters => 'see your engine for more info on those params', 
	},
=cut

has 'engine' => ( isa => 'HashRef', is => 'ro', required => 1 );

=head3 Message Parameters 

	debug   => sub { my $msg = shift; print "<<$msg\n" if $msg; },
	warning => sub { my $msg = shift; warn ">>$msg"    if $msg; },

=cut 

has 'debug'   => ( isa => 'CodeRef', is => 'ro', required => 0 );
has 'warning' => ( isa => 'CodeRef', is => 'ro', required => 0 );

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

=cut

subtype 'globalFormatsType', as 'HashRef', where {
	foreach my $prefix ( keys %{$_} ) {
		return if ( !_uriTest( $_->{$prefix} ) );
	}
	return 1;    #success
};

has 'globalFormats' => (
	isa      => 'globalFormatsType',
	is       => 'ro',
	required => 1
);

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

=cut

has 'setLibrary' => ( isa => 'HashRef', is => 'ro', required => 1 );

=head3 Other Parameters (Optional)

	xslt => '/oai2.xsl',

	Adds path to HTTP::OAI::Repsonse objects to modify output in browser.
	
	requestURL => 'http://bla.url'
	
	Overwrite normal requestURL, e.g. when using a reverse proxy etc.
	Note that requestURL specified during new is only the http://domain.com:port
	part (without ? followed by GET params), but that HTTP::OAI treats the
	complete URL as requestURL

=cut

has 'xslt'       => ( isa => 'Str', is => 'ro', required => 0 );
has 'requestURL' => ( isa => 'Uri', is => 'rw', required => 0 );

#INTERNAL (no initarg)

has 'OAIerrors' => (
	is       => 'rw',
	required => 0,                                 #really?
	init_arg => undef,
	isa      => 'HTTP::OAI::Response',
	default  => sub { HTTP::OAI::Response->new }
);

#
#
#

sub BUILD {
	my $self = shift or die "Need myself!";

	Debug( $self->debug )     if ( $self->debug );
	Warning( $self->warning ) if ( $self->warning );

	$self->{Engine} = new HTTP::OAI::DataProvider::Engine( %{ $self->engine } );
}

#
# VERBs
#

=method verb

	my $response=$provider->verb(%params);

=cut

sub verb {
	my $self = shift or die "Need myself";

	#dont croak here, prefer propper OAI error
	my %params = @_ or ();

	$self->resetErrorStack;    #not sure if this should be here
	$self->validateRequest(%params) or return $self->OAIerrors;

	if ( $params{verb} eq 'GetRecord' ) {
		return $self->_GetRecord(%params);
	}
	elsif ( $params{verb} eq 'Identify' ) {
		return $self->_Identify(%params);
	}
	elsif ( $params{verb} eq 'ListRecords' ) {
		return $self->_ListRecords(%params);
	}
	elsif ( $params{verb} eq 'ListSets' ) {
		return $self->_ListSets(%params);
	}
	elsif ( $params{verb} eq 'ListIdentifiers' ) {
		return $self->_ListIdentifiers(%params);
	}
	elsif ( $params{verb} eq 'ListMetadataFormats' ) {
		return $self->_ListMetadataFormats(%params);
	}
}

=method my $result=$provider->_GetRecord(%params);

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

sub _GetRecord {
	my $self   = shift;
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error

	my $engine        = $self->{Engine};
	my $globalFormats = $self->{globalFormats};

	# Error handling
	my $header = $engine->findByIdentifier( $params{identifier} );
	if ( !$header ) {
		$self->addError( code => 'idDoesNotExist' );
	}

	$self->checkFormatSupported( $params{metadataPrefix} );
	return $self->OAIerrors if ( $self->error );    ####

	# Metadata handling
	return $engine->query( \%params );
}

=method my $response=$provider->verb(verb->Identify);

Arguments: none

Errors: badArgument

The information for the identify response is assembled from two sources: from
configuration during new and from inspection of the system (earlierstDate, 
granularity).

=cut

sub _Identify {
	my $self = shift or die "Need myself";

	#my %params   = @_;
	#Debug "Enter Identify";

	my $identify = $self->identify;
	return $self->OAIerrors if $self->error;

	# Metadata munging
	my $response = HTTP::OAI::Identify->new(
		adminEmail     => $identify->{adminEmail},
		baseURL        => $identify->{baseURL},
		deletedRecord  => $identify->{deletedRecord},
		repositoryName => $identify->{repositoryName},
		requestURL     => $identify->{requestURL},

		#probably a demeter problem
		earliestDatestamp => $self->{Engine}->earliestDate(),
		granularity       => $self->{Engine}->granularity(),
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

sub _ListMetadataFormats {
	my $self = shift or die "Need myself";
	my %params = @_;
	return $self->OAIerrors if ( $self->error );

	my $engine = $self->{Engine};

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

	$self->error ? return $self->OAIerrors : return $list;
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

sub _ListIdentifiers {
	my $self = shift or croak "Need myself!";
	my %params = @_;

	my $engine = $self->{Engine}
	  or croak "Internal error: Data store missing!";

	if ( $params{resumptionToken} ) {

		#chunk has always been HTTP::OAI::Response object
		my $chunk = $engine->chunkExists(%params);
		return $chunk if $chunk;
		Debug "badResumptionToken 3";
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
	my $response = $engine->query( \%params )
	  or $self->addError( code => 'noRecordsMatch' );    
	#todo: check if at least one record. Where?
	$self->error ? return $self->OAIerrors : return $response;

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

sub _ListRecords {
	my $self   = shift;
	my %params = @_;
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

		#use Data::Dumper;
		Debug "badResumptionToken 1: CHUNK NOT FOUND for RT "
		  . $params{resumptionToken};    #. Dumper \%params;
		return $self->addError( code => 'badResumptionToken' );
	}

	$self->checkFormatSupported( $params{metadataPrefix} );

	return $self->OAIerrors if ( $self->error );

	# Metadata handling

	my $response = $engine->query( \%params )
	  or $self->addError( code => 'noRecordsMatch' );
	$self->error ? return $self->OAIerrors : return $response;
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

sub _ListSets {
	my $self = shift or croak "Provider missing!";
	my %params = @_;

	my $engine = $self->{Engine} or carp "Engine missing!";

	#Debug "Enter ListSets $self\n";

	#resumptionTokens not supported/TODO
	if ( $params{resumptionToken} ) {
		Debug "badResumptionToken 2";
		return $self->addError(
			code    => 'badResumptionToken',
			message => 'resumption token not yet supported with listsets'
		);
	}

	# Get the setSpecs from engine/store
	# TODO:test for noSetHierarchy has to be in SetLibrary
	my @used_sets = $engine->listSets
	  or $self->addError( code => 'noSetHierarchy' );

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
	$self->error ? return $self->OAIerrors : return $listSets;
}

#
# SUPPORT STUFF (PUBLIC)
#

=method my $xml=$self->asString($response);

Expects a HTTP::OAI::Response object and returns it as xml string. It applies
$self->{xslt} if set and also applies a current requestURL.

=cut

sub asString {
	my $self = shift or croak "Need myself";
	my $response = shift
	  or croak "No response";    #a HTTP::OAI::Response object
	                             #Debug "$response: " . $response;
	if ( $self->xslt ) {
		$response->xslt( $self->xslt ) or carp "problems with xslt!";
	}
	$response->requestURL( $self->requestURL );

	my $xml;
	$response->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
	$response->generate;

	return encode_utf8($xml);

#as per https://groups.google.com/forum/?fromgroups#!topic/psgi-plack/J0IiUanfgeU
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

#
# SUPPORT STUFF, private?
#

=method checkFormatSupported ($prefixWanted);

Expects a metadata prefix (as scalar). If it can't be disseminated an OAI 
error is added to OAIerror stack and checkFormatSupported return 0 (fail).
If format is supported, it returns 1 (success) and sets no error. 

	#Either
	$provider->checkFormatSupported( $prefix );
	if ($provider->error) {
		#do something
	}
	
	#Or
	$provider->checkFormatSupported( $prefix ) or return $self->OAIerror; 


=cut

sub checkFormatSupported {
	my $self         = shift or carp "Need self!";
	my $prefixWanted = shift or carp "Need something to test for";
	if ( !$self->{globalFormats}{$prefixWanted} ) {
		$self->addError( code => 'cannotDisseminateFormat' );
		return;
	}
	return 1;
}

=method $self->validateRequest(%params) or return $self->OAIerrors;

Expects params in hash. It saves potential errors in $provider->errorOAI and 
returns 1 on success (i.e. no validation error) or fails when validation showed
an error.

Should not be necessary anymore publicly...

=cut

sub validateRequest {
	my $self = shift or croak "Need myself!";
	my %params = @_ or ();    #dont croak here, prefer propper OAI error
	foreach my $err ( validate_request(%params) ) {
		Debug "validateRequest: found error" . $err->code . ':' . $err->message;
		$self->OAIerrors->errors($err);    #adds to error stack manually
		 #$self->addError(code=>$err->code, message=>$err->message);    #adds to error stack manually
	}

	#avoid HTTP::OAI::Response->is_error since it makes trouble
	if ( $self->error ) {
		return;    # error = request NOT valid
	}

	#Debug "validateRequest: found NO error";
	return 1;      #success = request is valid
}

=method $self->addError(code=>$code, message=>$message);

Expected is an error code and optionally an error message. If not specified, 
message will use default message for that error code. Returns a 
HTTP::OAI::Response object with the error stack. Croaks on failure.

TODO: Theoretically, I need a way to add multiple errors at once:

$self->addError([(code=>$code, message=>$message), (code=>$code, message=>$message)]);

Currently, on failire addError may die...

=cut

sub addError {
	my $self = shift or croak "Need myself";
	my %args = @_;
	die "Need error code!" if ( !$args{code} );

	$self->OAIerrors->errors( HTTP::OAI::Error->new(%args) );
	return $self->OAIerrors;

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
