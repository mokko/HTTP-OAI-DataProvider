package HTTP::OAI::DataProvider;

# ABSTRACT: A simple OAI data provider

use warnings;
use strict;
use Carp qw/croak carp/;
use Encode qw(encode_utf8);
use XML::SAX::Writer;
use URI;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_request/;
use HTTP::OAI::DataProvider::Engine;
use HTTP::OAI::DataProvider::SetLibrary;
use HTTP::OAI::DataProvider::Common qw/Debug Warning say/;

#use Data::Dumper qw/Dumper/; #for debugging

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

=head1 SYNOPSIS

	#Init
	use HTTP::OAI::DataProvider;
	my $provider = HTTP::OAI::DataProvider->new(%options);
	
	#Verbs: GetRecord, Identify ...
	my $response=$provider->$verb(%params);

	#$response is a string in OAI-PMH XML, either one of the six OAI 
	#verbs or an error. 

	#New Error Checking 
	if ($provider->OAIerror) {
		debug $provider->error;
		return $provider->OAIerror;	
	}

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

See OAI specification (Identify) for available options and details of 
parameters.

=head3 Engine Parameters

engine->{engine} specifies the engine you use. Everything else depends on the
engine you use. Engine parameters are handed down to the engine you use. 

This is an example configuration for DP::Engine::SQLite:

	engine => {
		chunkCache => {
			maxChunks       => 4000,    #was chunkCacheMaxSize
			recordsPerChunk => 10,      #was chunkSize
		},
		dbfile    => "$FindBin::Bin/../t/environment/db",
		engine    => 'HTTP::OAI::DataProvider::Engine::SQLite',
		locateXSL => sub {
			my $prefix       = shift;
			my $nativePrefix = ( keys %{ $config{engine}{nativeFormat} } )[0]
			  or die "nativePrefix missing";
			return "$FindBin::Bin/../t/environment/$nativePrefix" . '2'
			  . "$prefix.xsl";
		},
		nativeFormat => { 'mpx' => 'http://www.mpx.org/mpx' }
	},

=head3 Message Parameters 

	messages => {
		debug   => sub { my $msg = shift; print "<<$msg\n" if $msg; },
		warning => sub { my $msg = shift; warn ">>$msg"    if $msg; },
	},

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
			  . ' (ursprünglich für DISMARC exportiert)'
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

sub BUILD {
	my $self = shift or die "Need myself!";

	Debug( $self->debug )     if ( $self->debug );
	Warning( $self->warning ) if ( $self->warning );

	$self->{Engine} = new HTTP::OAI::DataProvider::Engine( %{ $self->engine } );
}

=method my $result=$provider->GetRecord(%params);

All verbs expect params as hash and return a response as an xml string.

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
	my @errors;

	$params{verb} = 'GetRecord';
	$self->_validateRequest(%params) or return $self->OAIerror;

	my $engine        = $self->{Engine};
	my $globalFormats = $self->{globalFormats};

	# Error handling
	my $header = $engine->findByIdentifier( $params{identifier} );
	if ( !$header ) {
		push( @errors, new HTTP::OAI::Error( code => 'idDoesNotExist' ) );
	}

	if ( my $e = $self->checkFormatSupported( $params{metadataPrefix} ) ) {
		push @errors, $e;    #check if metadataFormat is supported
	}

	if (@errors) {
		$self->raiseOAIerrors(@errors);
		return $self->OAIerror;
	}

	# Metadata handling
	my $response = $engine->query( \%params );    #todo
	return $self->_output($response);
}

=method my $response=$provider->Identify([%params]);

Arguments: none

Errors: badArgument

The information for the identify response is assembled from two sources: from
configuration during new and from inspection of the system (earlierstDate, 
granularity).

=cut

sub Identify {
	my $self   = shift;
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error
	my $identify = $self->identify;
	$params{verb} = 'Identify';
	$self->_validateRequest(%params) or return $self->OAIerror;

	#Debug "Enter Identify";

	# Metadata munging
	my $obj = new HTTP::OAI::Identify(
		adminEmail    => $identify->{adminEmail},
		baseURL       => $identify->{baseURL},
		deletedRecord => $identify->{deletedRecord},

		#probably a demeter problem
		earliestDatestamp => $self->{Engine}->earliestDate(),
		granularity       => $self->{Engine}->granularity(),
		repositoryName    => $identify->{repositoryName},
		requestURL        => $identify->{requestURL},
	) or return "Cannot create new HTTP::OAI::Identify";

	return $self->_output($obj);    #success
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

sub ListMetadataFormats {
	my $self = shift;

	Warning ' Enter ListMetadataFormats ';
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error
	$params{verb} = 'ListMetadataFormats';
	my $engine = $self->{Engine};

	#
	# Error handling
	#
	$self->_validateRequest(%params) or return $self->OAIerror;

	#only if there is actually an identifier
	if ( $params{identifier} ) {
		my $header = $engine->findByIdentifier( $params{identifier} );
		if ( !$header ) {
			$self->raiseOAIerror('idDoesNotExist');
			return;
		}
	}

	#Metadata Handling
	my $list = new HTTP::OAI::ListMetadataFormats;
	foreach my $prefix ( keys %{ $self->{globalFormats} } ) {

		#print "prefix:$prefix\n";
		my $format = new HTTP::OAI::MetadataFormat;
		$format->metadataPrefix($prefix);
		$format->schema( $self->{globalFormats}{$prefix}{ns_schema} );
		$format->metadataNamespace( $self->{globalFormats}{$prefix}{ns_uri} );
		$list->metadataFormat($format);
	}

	#ListMetadataFormat has requestURL info, so recreate it
	#mk sure we don' t lose requestURL in Starman
	if ( $self->requestURL ) {
		$list->requestURL( $self->requestURL );
	}

	#check if noMetadataFormats
	if ( $list->metadataFormat() == 0 ) {
		$self->raiseOAIerror('noMetadataFormats');
		return;
	}

	return $self->_output($list);    #success
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
	my $engine = $self->{Engine}
	  or croak "Internal error: Data store missing!";
	my %params = @_
	  or ();       #dont croak here, prefer propper OAI error
	my @errors;    #stores errors before there is a result object
	$params{verb} = 'ListIdentifiers';

	$self->_validateRequest(%params) or return $self->OAIerror;

	#my $request = $self->requestURL();

	if ( $params{resumptionToken} ) {

		#chunk is response object here!
		my $chunk = $engine->chunkExists(%params);

		if ($chunk) {
			return $self->_output($chunk);    #success
		}
		$self->raiseOAIerror('badResumptionToken');
		return $self->OAIerror;               #success

	}

	if ( my $e = $self->checkFormatSupported( $params{metadataPrefix} ) ) {
		push @errors, $e;                     #cannotDisseminateFormat
	}

	if ( $params{Set} ) {

		#sets defined in data store
		my @used_sets = $engine->listSets;

		#query contains sets, but data has no set defined
		if ( !@used_sets ) {
			push @errors, new HTTP::OAI::Error( code => 'noRecordsMatch' );
		}
	}

	if (@errors) {
		$self->raiseOAIerrors(@errors);
		return $self->OAIerror;    #success
	}

	#Metadata handling: query returns response
	#always only the first chunk
	my $response = $engine->query( \%params );    #todo!

	if ( !$response ) {
		$self->{error} =
		  $self->err2XML( new HTTP::OAI::Error( code => 'noRecordsMatch' ) );
		return;                                   #error
	}

	#Debug "RESPONSE:".$response;
	#todo: check if at least one record. On which level?
	return $self->_output($response);
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
	my $self   = shift;
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error
	$params{verb} = 'ListRecords';
	$self->_validateRequest(%params) or return $self->OAIerror;

	#Warning 'Enter ListRecords (prefix:' . $params->{metadataPrefix};

	#Debug 'from:' . $params->{from}   if $params->{from};
	#Debug 'until:' . $params->{until} if $params->{until};
	#Debug 'set:' . $params->{set}     if $params->{set};
	#Debug 'resumption:' . $params->{resumptionToken}
	#  if $params->{resumptionToken};

	my @errors;
	my $engine = $self->{Engine};

	# Error handling

	if ( $params{resumptionToken} ) {
		my $chunk = $engine->chunkExists(%params);
		if ($chunk) {
			return $self->_output($chunk);
		}
		$self->{error} = $self->err2XML(
			new HTTP::OAI::Error( code => 'badResumptionToken' ) );
		return;    #error
	}

	if ( my $e = $self->checkFormatSupported( $params{metadataPrefix} ) ) {
		push @errors, $e;    #cannotDisseminateFormat
	}

	if (@errors) {
		$self->{error} = $self->err2XML(@errors);
		return;              #errors
	}

	# Metadata handling

	my $response = $engine->query( \%params, $self->requestURL );    #todo!

	if ( !$response ) {
		$self->raiseOAIerror('noRecordsMatch');
		return;
	}

	return $self->_output($response);
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
	my $self   = shift;
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error

	my $engine = $self->{Engine};

	$params{verb} = 'ListSets';
	$self->_validateRequest(%params) or return $self->OAIerror;

	#print "Enter ListSets $self\n";

	#errors in using this package...
	croak "Engine missing!"   if ( !$engine );
	croak "Provider missing!" if ( !$self );

	#resumptionTokens not supported/TODO
	if ( $params{resumptionToken} ) {
		$self->raiseOAIerror('badResumptionToken');
		return;
	}

	# Get the setSpecs from engine/store
	# TODO:test for noSetHierarchy has to be in SetLibrary
	my @used_sets = $engine->listSets;

	#if none then noSetHierarchy (untested)
	if ( !@used_sets ) {
		$self->raiseOAIerror('noSetHierarchy');
		return $self->errorOAI;
	}

	my $listSets = $self->_processSetLibrary();

	my $library = new HTTP::OAI::DataProvider::SetLibrary();
	$library->addListSets($listSets)
	  or die "Error: some error occured in library->addListSet";

	if ( !$library ) {

		Warning "setLibrary cannot be loaded, proceed without setNames and "
		  . "setDescriptions";

		foreach (@used_sets) {
			my $s = new HTTP::OAI::Set;
			$s->setSpec($_);
			$listSets->set($s);
		}
	}
	else {
		$listSets = $library->expand(@used_sets);
	}

	#mk sure we don't lose requestURL in Starman
	if ( $self->requestURL() ) {
		$listSets->requestURL( $self->requestURL() );
	}

	return $self->_output($listSets);
}

=method return $provider->error;

Returns an internal error message (if any). Error message is a single scalar 
(string). TODO: at the monent it is not guaranteed to have an error every time
an error actually occured. See OAIerror instead.

Just a getter, no setter! The error is set internally, e.g.
	$provider->_validateRequest (%params) or return provider->error;

=cut

sub error {
	my $self = shift or croak "Need myself!";
	return $self->{error} if ( $self->{error} );
}

=method return $provider->errorOAI;

Returns an internal error message (if any). Error message is a single scalar 
(string). Just a getter, no setter! 

=cut

sub OAIerror {
	my $self = shift or croak "Need myself!";
	return $self->{OAIerror} if ( $self->{OAIerror} );
}

=method checkFormatSupported ($prefixWanted);

Expects a prefix for a metadataPrefix (as scalar), returns an OAI error if the 
format cannot be disseminated. Returns nothing on success, so you can do:

	if ( my $e = $self->checkFormatSupported( $params->{metadataPrefix} ) ) {
		push @errors, $e;
	}

=cut

sub checkFormatSupported {
	my $self         = shift or carp "Need self!";
	my $prefixWanted = shift or carp "Need something to test for";
	if ( !$self->{globalFormats}{$prefixWanted} ) {
		return new HTTP::OAI::Error( code => 'cannotDisseminateFormat' );
	}
	return;    #empty is success here
}

=method my $xml=$provider->err2XML(@obj);

Parameter is an array of HTTP::OAI::Error objects. 

(Now works with multiple OAI errors.)

=cut

sub err2XML {
	my $self = shift;
	return if ( !@_ );
	my $response = new HTTP::OAI::Response;
	foreach (@_) {
		$response->errors($_) if ( ref $_ eq 'HTTP::OAI::Error' );
	}

	#$response=$self->overwriteRequestURL($response);
	$self->overwriteRequestURL($response);
	$self->_init_xslt($response);
	return $response->toDOM->toString;

	#return _output($response);
}

=method $self->raiseOAIerrors (@errors);

Expects a list of HTTP::OAI errors. Sets xml string version of the error 
message which can be retrieved using $self->error.

=cut

sub raiseOAIerrors {
	my $self = shift or die "Need myself";
	if (@_) {
		$self->{OAIerror} = $self->err2XML(@_);
	}
}

=method $self->raiseOAIerror('noRecordsMatch', 'optional message');

Expects an OAI error code as string. The error message is optional. Sets the 
error message which can be retrieved using $self->error.

=cut

sub raiseOAIerror {
	my $self = shift or croak "Need myself!";
	my $code = shift or croak "Need code!";
	my %opts = ( code => $code );

	if ( my $msg = shift ) {
		$opts{message} = $msg;
	}

	$self->{OAIerror} = $self->err2XML( new HTTP::OAI::Error(%opts) );
}

=method my $xml=$self->_output($response);

Expects a HTTP::OAI::Response object and returns it as xml string. It applies
$self->{xslt} if set.

=cut

sub _output {
	my $self     = shift;
	my $response = shift
	  or croak "No response";    #a HTTP::OAI::Response object

	$self->_init_xslt($response);    #response is a HTTP::OAI::$verb object
	$response = $self->overwriteRequestURL($response);

	#alternative output
	#return encode_utf8($response->toDOM->toString);
	#there is some error here
	my $xml;
	$response->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
	$response->generate;
	return encode_utf8($xml);

#as per https://groups.google.com/forum/?fromgroups#!topic/psgi-plack/J0IiUanfgeU
}

=method $obj= $self->overwriteRequestURL($obj)

If $provider->{requestURL} exists take that value and overwrite the requestURL
in the responseURL. requestURL specified in this module consists only of
	http://blablabla.com:8080

All params following the question mark are preserved.

I use this to correct the url of data provider which is hosted on two different 
server. One hosts the perl webapp and the other one caches the app for the 
public.

=cut

sub overwriteRequestURL {
	my $self = shift or croak "Need myself";
	my $response = shift
	  or croak "Need response";    #e.g. HTTP::OAI::ListRecord

	return $response if ( !$self->requestURL );

	#replace part before question mark
	if ( $response->requestURL =~ /\?/ ) {

		my @f = split( /\?/, $response->requestURL, 2 );
		if ( $f[1] ) {
			my $new = $self->requestURL . '?' . $f[1];

			#very dirty
			if ( $new =~ /verb=/ ) {

				#why? untested
				$self->{engine}->{chunkRequest}->{_requestURI} = $new;
			}
			else {

				#why? untested
				$new = $self->{engine}->{chunkRequest}->{_requestURI};
			}

			$response->requestURL($new);
			return $response;

			#Debug "overwriteRequestURL: "
			#  . $response->requestURL . '->'
			#  . $new;
		}
	}
	else {    #requestURL has no ? in case of an badVerb
		$response->requestURL( $self->requestURL );
	}
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

sub _uriTest {
	my $format = shift or croak "Need format!";
	my @keys = qw (ns_uri ns_schema);

	foreach my $key (@keys) {
		if ( !$format->{$key} ) {

			#print "$key not defined\n";
			return;
		}
		my $uri = URI->new( $format->{$key} );
		if ( !$uri->scheme ) {

			#print "ns_uri is not URI\n";
			return;
		}
	}
	return 1;    #exists and is uri
}

=method $self->_validateRequest(%params) or return $self->error;

You may want to write $self->_validateRequest(verb=>'GetRecord', %params) if 
params does not include a verb.

=cut

sub _validateRequest {
	my $self = shift or croak "Need myself!";
	my %params = @_
	  or ();    #dont croak here, prefer propper OAI error

	my @errors = validate_request(%params);
	if (@errors) {
		$self->{OAIerror} = $self->err2XML(@errors);
		return;    #there was an error during validation
	}
	return 1;      #no validation error (success)
}

sub _processSetLibrary {
	my $self = shift or croak "Need myself!";

	#debug "Enter salsa_setLibrary";
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

__PACKAGE__->meta->make_immutable;
1;
