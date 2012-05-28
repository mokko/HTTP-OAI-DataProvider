package HTTP::OAI::DataProvider;

# ABSTRACT: A simple OAI data provider

use warnings;
use strict;
use Carp qw/croak carp/;
use Moose;
use namespace::autoclean;

use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_request/;
use HTTP::OAI::DataProvider::SetLibrary;
use HTTP::OAI::DataProvider::ChunkCache;
use HTTP::OAI::DataProvider::Transformer;
use HTTP::OAI::DataProvider::SQLite;

#TODO: not sure if Message works.
use HTTP::OAI::DataProvider::Message qw/Debug Warning/;

#use Data::Dumper qw/Dumper/; #for debugging

=head1 SYNOPSIS

	#Init
	use HTTP::OAI::DataProvider;
	my $provider = HTTP::OAI::DataProvider->new($options);

	#Verbs: GetRecord, Identify ...
	my $response=$provider->$verb($request, %params);

	#Error checking
	my $e=$response->isError
	if ($response->isError) {
	 #do this
	}

	#Debugging (TODO)
	Debug "message";
	Warning "message";

=method my $provider->new ($options);

Initialize the HTTP::OAI::DataProvider object with the options of your choice.

On failure return nothing; in case this the error is likely to occur during
development and not during runtime it may also croak.

=head3 Parameters

* adminEmail =>'bla@email.com': see OAI specification for details.

* baseURL =>'http://base.url': see OAI specification for details.

* chunkCacheMaxSize => 4000:
What is the maximum number of chunks I should store in memory before beginning 
to delete old chunks? chunkSize * chunkCacheMaxSize = the maximum number of 
records the data provider can return in one request.
	
* chunkSize         => 10
	How many records make up one chunk? See chunkCacheMaxSize.

* dbfile => 'path/to/dbfile'
	TODO: DB stuff needs better abstraction

* deletedRecord => 'transient'
	TODO: deletedRecord should not be mandatory. It should default to a meaningful
	default instead see OAI specification for details.

* GlobalFormats => {
		oai_dc => {
			ns_uri    => "http://www.openarchives.org/OAI/2.0/oai_dc/",
			ns_schema => "http://www.openarchives.org/OAI/2.0/oai_dc.xsd",
		},
	},

* locateXSL      => sub {
	my $prefix = shift or croak "Need prefix";
	return "someDir/$prefix.xsl";
  }
  callback which locates the xsl for a specific prefix. Expects a prefix and 
  returns a path.

* nativePrefix   => 'mpx'

* native_ns_uri =>'http://bla'
	TODO: should be called nativeURI

	TODO: should be combined with nativePrefix, e.g.
	nativeNamespace => bla => { 'http://bla'};

* repositoryName => 'Repo Name Example'
	see OAI specification for details

=head3 OPTIONS

=for :list

* debug=>callback [OPTIONAL TODO]
	If a callback is supplied use this callback for debug output

* isMetadaFormatSupported=>callback [OPTIONAL TODO]
	The callback expects a single prefix and returns 1 if true and nothing
	when not supported. Currently only global metadataFormats, i.e. for all
	items in repository. This one seems to be obligatory, so croak when
	missing.

* xslt=>'path/to/style.xslt' [OPTIONAL TODO]
	Adds this path to HTTP::OAI::Repsonse objects to modify output in browser.
	[Doc TODO. Info should be here not in _init_xslt]

	Except engine information, nothing no option seems to be required and it is
	still uncertain, maybe even unlikely if engine will be option at all.
	(Alternative would be to just to use the engine.)

* requestURL [OPTIONAL]
	Overwrite normal requestURL, e.g. when using a reverse proxy cache etc.
	Note that
	a) requestURL specified during new is only the http://domain.com:port
	part (without ? followed by GET params), but that HTTP::OAI treats the
	complete URL as requestURL
	b) badVerb has no URL and no question mark
	c) in modern OAI specification it is actually called request and requestURL

	Currently, requestURL evaporates if Salsa_OAI is run under anything else
	than HTTP::Server::Simple.

* warning =>callback [OPTIONAL Todo]
	If a callback is supplied use this callback for warning output

=cut

#required
has 'adminEmail'        => ( isa => 'Str',     is => 'ro', required => 1 );
has 'baseURL'           => ( isa => 'Str',     is => 'ro', required => 1 );
has 'chunkCacheMaxSize' => ( isa => 'Str',     is => 'ro', required => 1 );
has 'chunkSize'         => ( isa => 'Int',     is => 'ro', required => 1 );
has 'deletedRecord'     => ( isa => 'Str',     is => 'ro', required => 1 );
has 'dbfile'            => ( isa => 'Str',     is => 'ro', required => 1 );
has 'GlobalFormats'     => ( isa => 'HashRef', is => 'ro', required => 1 );
has 'locateXSL'         => ( isa => 'CodeRef', is => 'ro', required => 1 );
has 'nativePrefix'      => ( isa => 'Str',     is => 'ro', required => 1 );
has 'native_ns_uri'     => ( isa => 'Str',     is => 'ro', required => 1 );
has 'repositoryName'    => ( isa => 'Str',     is => 'ro', required => 1 );
has 'setLibrary'        => ( isa => 'HashRef', is => 'ro', required => 1 );

#optional
has 'Debug'      => ( isa => 'CodeRef', is => 'ro', required => 0 );
has 'Warning'    => ( isa => 'CodeRef', is => 'ro', required => 0 );
has 'requestURL' => ( isa => 'Str',     is => 'rw', required => 0 );    #todo!

sub BUILD {
	my $self = shift;

	$self->{chunkCache} =
	  new HTTP::OAI::DataProvider::ChunkCache(
		maxSize => $self->chunkCacheMaxSize )
	  or croak "Cannot init chunkCache";

	#check if info complete
	foreach my $prefix ( keys %{ $self->GlobalFormats } ) {
		if (   !${ $self->GlobalFormats }{$prefix}{ns_uri}
			or !${ $self->GlobalFormats }{$prefix}{ns_schema} )
		{
			die "GlobalFormat $prefix in configuration incomplete";
		}
	}

	#init engine (todo: this is noT properly abstracted)
	$self->{engine} = new HTTP::OAI::DataProvider::SQLite(
		dbfile       => $self->dbfile,
		chunkCache   => $self->{chunkCache},
		chunkSize    => $self->chunkSize,       # might not be necessary
		nativePrefix => $self->nativePrefix,
		nativeURI    => $self->native_ns_uri,
		transformer => new HTTP::OAI::DataProvider::Transformer(
			nativePrefix => $self->nativePrefix,
			locateXSL    => $self->locateXSL,
		),
	);
}

=method my $result=$provider->GetRecord(%params);

Arguments

=for :list
* identifier (required)
* metadataPrefix (required)

Errors

=for :list
* DbadArgument: already tested
* cannotDisseminateFormat: gets checked here
* idDoesNotExist: gets checked here

=cut

sub GetRecord {
	my $self    = shift;
	my %params  = @_;
	my @errors;

	#NEW (todo in other verbs plus testing!)
	$params{verb} = 'GetRecord';
	$self->_validateRequest(%params) or return $self->errormsg;

	Warning 'Enter GetRecord (id:'
	  . $params{identifier}
	  . 'prefix:'
	  . $params{metadataPrefix} . ')';

	my $engine        = $self->{engine};
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
		return $self->err2XML(@errors);
	}

	# Metadata handling
	my $response = $engine->query( \%params, $self->requestURL() );

	#todo: we still have to test if result has any result at all
	#mk sure we don't lose requestURL in Starman
	#$result->requestURL($request);

	# Check result

	#Debug "check results";
	#checkRecordsMatch is now done inside query

	# Return
	return $self->_output($response);

}

=method my $response=$provider->Identify($requestURL,$params);


=cut

sub Identify {
	my $self = shift;
	my %params     = @_;

	$params{verb} = 'Identify';
	$self->_validateRequest(%params) or return $self->errormsg;

	#Debug "Enter Identify ($request)";

	# Metadata munging
	my $obj = new HTTP::OAI::Identify(
		adminEmail        => $self->adminEmail,
		baseURL           => $self->baseURL,
		deletedRecord     => $self->deletedRecord,
		#probably a demeter problem
		earliestDatestamp => $self->{engine}->earliestDate(),
		granularity       => $self->{engine}->granularity(),
		repositoryName    => $self->repositoryName,
		requestURL        => $self->requestURL,
	) or return "Cannot create new HTTP::OAI::Identify";

	# Output
	return $self->_output($obj);
}

=method ListMetadataFormats (identifier);

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
	my $self    = shift;

	Warning 'Enter ListMetadataFormats';
	my %params = @_;
	$params{verb} = 'ListMetadataFormats';
	$self->_validateRequest(%params) or return $self->errormsg;

	my $engine = $self->{engine};    #TODO test

	#
	# Error handling
	#

	#only if there is actually an identifier
	if ( $params{identifier} ) {
		my $header = $engine->findByIdentifier( $params{identifier} );
		if ( !$header ) {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'idDoesNotExist' ) );
		}
	}

	#Metadata Handling
	my $list = new HTTP::OAI::ListMetadataFormats;
	foreach my $prefix ( keys %{ $self->{GlobalFormats} } ) {

		#print "prefix:$prefix\n";
		my $format = new HTTP::OAI::MetadataFormat;
		$format->metadataPrefix($prefix);
		$format->schema( $self->{GlobalFormats}{$prefix}{ns_schema} );
		$format->metadataNamespace( $self->{GlobalFormats}{$prefix}{ns_uri} );
		$list->metadataFormat($format);
	}

	#ListMetadataFormat has requestURL info, so recreate it from $params
	#mk sure we don't lose requestURL in Starman
	if ($self->{requestURL}) {
	$list->requestURL($self->{requestURL});
	}
	#check if noMetadataFormats
	if ( $list->metadataFormat() == 0 ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noMetadataFormats' ) );
	}

	#
	# Return
	#

	return $self->_output($list);
}

=method my $xml=$provider->ListIdentifiers ($params);

Returns xml as string, either one or multiple errors or a ListIdentifiers verb.

The Spec in my words: This verb is an abbreviated form of ListRecords,
retrieving only headers rather than headers and records. Optional arguments
permit selective harvesting of headers based on set membership and/or
datestamp.

Depending on the repository's support for deletions, a returned header may have
a status attribute of "deleted" if a record matching the arguments specified in
the request has been deleted.

ARGUMENTS

=for :list
* from (optional, UTCdatetime value)
* until (optional, UTCdatetime value)
* metadataPrefix (required)
* set (optional)
* resumptionToken (exclusive) 

ERRORS

=for :list
* badArgument: already checked in validate_request
* badResumptionToken: here
* cannotDisseminateFormat: here
* noRecordsMatch:here
* noSetHierarchy: here. Can only appear if query has set

LIMITATIONS
By making the metadataPrefix required, the specification suggests that
ListIdentifiers returns different sets of headers depending on which
metadataPrefix is chose. HTTP:OAI::DataProvider assume, however, that there are
only global metadata formats, so it will return the same set for all supported
metadataFormats.

TODO

=for :list
* Hierarchical sets

=cut

sub ListIdentifiers {
	my $self   = shift;
	my %params = @_;
	my @errors;    #stores errors before there is a result object

	$params{verb} = 'ListIdentifiers';
	$self->_validateRequest(%params) or return $self->errormsg;

	my $request       = $self->requestURL();
	my $engine        = $self->{engine};          #provider
	my $globalFormats = $self->{globalFormats};

	#Warning 'Enter ListIdentifiers (prefix:' . $params->{metadataPrefix};
	#Debug 'from:' . $params->{from}   if $params->{from};
	#Debug 'until:' . $params->{until} if $params->{until};
	#Debug 'set:' . $params->{set}     if $params->{set};
	#Debug 'resumption:' . $params->{resumptionToken}
	#  if $params->{resumptionToken};

	# Error handling
	if ( !$engine ) {
		croak "Internal error: Data store missing!";
	}

	if ( $params{resumptionToken} ) {

		#chunk is response object here!
		my $chunk = $self->chunkExists( \%params, $request ); #todo

		if ($chunk) {

			#Debug "Get here";
			return $self->_output($chunk);
		}
		else {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'badResumptionToken' ) );
		}
	}

	if ( my $e = $self->checkFormatSupported( $params{metadataPrefix} ) ) {
		push @errors, $e;    #cannotDisseminateFormat
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
		Debug "@errors" . @errors;
		return $self->err2XML(@errors);
	}

	#Metadata handling: query returns response
	#always only the first chunk
	my $response = $engine->query( \%params, $request ); #todo!

	if ( !$response ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noRecordsMatch' ) );
	}

	#Debug "RESPONSE:".$response;
	#todo: check if at least one record. On which level?
	# Return
	return $self->_output($response);
}

#where is it called?
sub _badResumptionToken {
	my $self = shift;
	return $self->err2XML(
		new HTTP::OAI::Error( code => 'badResumptionToken' ) );
}

=method ListRecords

returns multiple items (headers plus records) at once. In its capacity to
return multiple objects it is similar to the other list verbs
(ListIdentifiers). ListRecord also has the same arguments as ListIdentifier.
In its capacity to return full records (incl. header), ListRecords is similar
to GetRecord.

ARGUMENTS

=for :list
* from (optional, UTCdatetime value) TODO: Check if it works
* until (optional, UTCdatetime value)  TODO: Check if it works
* metadataPrefix (required unless resumptionToken)
* set (optional)
* resumptionToken (exclusive)

ERRORS

=for :list
* badArgument: checked for before you get here
* badResumptionToken - TODO
* cannotDisseminateFormat - TODO
* noRecordsMatch - here
* noSetHierarchy - TODO

TODO

=for :list
* Check if error appears as excepted when non-supported metadataFormat

=cut

sub ListRecords {
	my $self = shift;
	my %params = @_;
	$params{verb} = 'ListRecords';
	$self->_validateRequest(%params) or return $self->errormsg;

	#Warning 'Enter ListRecords (prefix:' . $params->{metadataPrefix};

	#Debug 'from:' . $params->{from}   if $params->{from};
	#Debug 'until:' . $params->{until} if $params->{until};
	#Debug 'set:' . $params->{set}     if $params->{set};
	#Debug 'resumption:' . $params->{resumptionToken}
	#  if $params->{resumptionToken};

	my @errors;
	my $engine  = $self->{engine};
	my $request = $self->{requestURL};

	#
	# Error handling
	#

	if ( $params{resumptionToken} ) {
		my $chunk = $self->chunkExists( \%params, $request );    #todo!
		if ($chunk) {
			return $self->_output($chunk);
		}
		else {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'badResumptionToken' ) );
		}
	}

	if ( my $e = $self->checkFormatSupported( $params{metadataPrefix} ) ) {
		push @errors, $e;    #cannotDisseminateFormat
	}

	return $self->err2XML(@errors) if (@errors);

	#
	# Metadata handling
	#

	my $response = $engine->query( \%params, $request );    #todo!

	if ( !$response ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noRecordsMatch' ) );
	}

	#checkRecordsMatch is now done inside query
	# Check result
	#if ( $result->isError ) {
	#	return $self->err2XML( $result->isError );
	#}

	# Return
	return $self->_output($response);
}

=method ListSets

ARGUMENTS

=for :list
* resumptionToken (optional)

ERRORS

=for :list
* badArgument -> HTTP::OAI::Repository
* badResumptionToken  -> here
* noSetHierarchy --> here

=cut

sub ListSets {
	my $self   = shift;
	my %params = @_;

	my $engine  = $self->{engine};
	my $request = $self->requestURL();    #check if this is still necessary!

	$params{verb} = 'ListSets';
	$self->_validateRequest(%params) or return $self->errormsg;

	#print "Enter ListSets $self\n";

	#
	# Check for errors
	#

	#errors in using this package...
	croak "Engine missing!"   if ( !$engine );
	croak "Provider missing!" if ( !$self );

	#resumptionTokens not supported/TODO
	if ( $params{resumptionToken} ) {

		#Debug "resumptionToken";
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'badResumptionToken' ) );
	}

	#
	# Get the setSpecs from engine/store
	#

	#TODO:test for noSetHierarchy has to be in SetLibrary
	my @used_sets = $engine->listSets;

	#
	# Check results
	#

	#if none then noSetHierarchy (untested)
	if ( !@used_sets ) {

		#		debug "no sets";
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noSetHierarchy' ) );
	}

	# just for debug
	#foreach (@used_sets) {
	#	Debug "used_sets: $_\n";
	#}

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
	#
	#output fun!
	#
	return $self->_output($listSets);
}

#
#
#

=head1 PUBLIC UTILITY FUNCTIONS / METHODS

check error, display error, warning, debug etc.

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
	if ( !$self->{GlobalFormats}{$prefixWanted} ) {
		return new HTTP::OAI::Error( code => 'cannotDisseminateFormat' );
	}
	return;    #empty is success here
}

=method my $xml=$provider->err2XML(@obj);

Parameter is an array of HTTP::OAI::Error objects. Of course, also a single
value.

Includes the nicer output stylesheet setting from init.

=cut

sub err2XML {
	my $self = shift;

	if (@_) {
		my $response = new HTTP::OAI::Response;
		my @errors;
		foreach (@_) {
			if ( ref $_ ne 'HTTP::OAI::Error' ) {
				croak ref $_;
				croak "Internal Error: Error has wrong format!";
			}
			$response->errors($_);
			push @errors, $response;
		}

		$self->overwriteRequestURL($response);
		$self->_init_xslt($response);
		return $response->toDOM->toString;

		#return _output($response);
	}
}

#
# PRIVATE STUFF
#

=head1 PRIVATE METHODS

HTTP::OAI::DataProvider is to be used by frontend developers. What is not meant
for them, is private.

=head2 my $chunk=$self->chunkExists ($params, [$request]);

TODO: should be called getChunkDesc

Tests whether

=for :list
* whether a resumptionToken is in params and
* there is a chunkDesc with that token in the cache.

It returns either a chunkDesc or nothing.

Usage:
	my $chunk=$self->chunkExists ($params)
	if (!$chunk) {
		return new HTTP::OAI::Error (code=>'badResumptionToken');
	}

=cut

sub chunkExists {
	my $self    = shift;
	my $params  = shift;
	my $request = $self->requestURL;    #should be optional, but isn't, right?
	my $token      = $params->{resumptionToken} or return;
	my $chunkCache = $self->{chunkCache};

	if ( !$chunkCache ) {
		carp "No chunkCache!";
	}

	#Debug "Query chunkCache for " . $token;

	my $chunkDesc = $chunkCache->get($token)
	  or return;            #possibly we need a return here!

	#chunk is a HTTP::OAI::Response object
	my $response = $self->{engine}->queryChunk( $chunkDesc, $params, $request );
	return $response;
}

=head2 $self->_output($response);

Expects a HTTP::OAI::Response object and returns it as xml string. It applies
$self->{xslt} if set.

=cut

sub _output {
	my $self     = shift;
	my $response = shift;    #a HTTP::OAI::Response object

	if ( !$response ) {
		die "No response!";
	}

	$self->_init_xslt($response);

	#overwrites real requestURL with config value
	$self->overwriteRequestURL($response);

	#return $dom=$response->toDOM->toString;

	my $xml;
	$response->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
	$response->generate;
	return $xml;
}

=head2 $obj= $self->overwriteRequestURL($obj)

If $provider->{requestURL} exists take that value and overwrite the requestURL
in the responseURL. requestURL specified in this module consists only of
	http://blablabla.com:8080
All params following the quetion mark will be preserved.
$provider->{requestURL} should a config value, e.g. to make the cache appear
to be real.

=cut

sub overwriteRequestURL {
	my $self     = shift;    #$provider
	my $response = shift;    #e.g. HTTP::OAI::ListRecord

	if ( !$response ) {
		carp "Cannot overwrite without a response!";
	}

	if ( $self->{requestURL} ) {

		#replace part before question mark
		if ( $response->requestURL =~ /\?/ ) {
			my @f = split( /\?/, $response->requestURL, 2 );
			if ( $f[1] ) {
				my $new = $self->{requestURL} . '?' . $f[1];

				#very dirty
				if ( $new =~ /verb=/ ) {
					$self->{engine}->{chunkRequest}->{_requestURI} = $new;
				}
				else {
					$new = $self->{engine}->{chunkRequest}->{_requestURI};
				}

				$response->requestURL($new);

				#Debug "overwriteRequestURL: "
				#  . $response->requestURL . '->'
				#  . $new;
			}
			else {

				#requestURL has no ? in case of an badVerb
				$response->requestURL( $self->{requestURL} );
			}
		}
	}
}

=head2 $obj= $self->_init_xslt($obj)

For an HTTP::OAI::Response object ($obj), sets the stylesheet to the value
specified during init. This assume that there is only one stylesheet.

This may be a bad name, since not specific enough. This xslt is responsible
for a nicer look and added on the top of reponse headers.

=cut

sub _init_xslt {
	my $self = shift;
	my $obj  = shift;    #e.g. HTTP::OAI::ListRecord
	if ( !$obj ) {
		Warning "init_xslt called without a object!";
		return ();
	}

	#Debug "Enter _init_xslt obj:$obj"; #beautify
	if ( $self->{xslt} ) {
		$obj->xslt( $self->{xslt} );
	}
	else {
		Warning "No beautify-xslt loaded!";
	}
}

#$self->_validateRequest( verb=>'GetRecord', %params ) or return $self->error;
sub _validateRequest {
	my $self   = shift or croak "Need myself!";
	my %params = @_    or return;
	if ( my @errors = validate_request(%params) ) {
		$self->{errormsg} = $self->err2XML(@errors);
		return;    #there was an error during validation
	}
	return 1;      #no validation error (success)
}

sub errormsg {
	my $self = shift or croak "Need myself!";
	if ( $self->{errormsg} ) {
		return $self->{errormsg};
	}
}

=head1 OAI DATA PROVIDER FEATURES

SUPPORTED

=begin :list

* the six OAI verbs (getRecord, identify, listRecords, listMetadataFormats,
 listIdentifiers, listSets) and all errors from OAI-PMH v2 specification
* resumptionToken
* sets
* deletedRecords (only transiently?)

=end :list

NOT SUPPORTED

=begin :list

* hierarchical sets

=end :list

=head1 TODO

Currently, I use Dancer::CommandLine. Maybe I should build such a mechanism
into DataProvider which would also allow to choose a Debug and Warning
routine via config, something like

	my $provider = HTTP::OAI::DataProvider->new(
		debug=>'SalsaOAI::Debug',
		warning=>'SalsaOAI::Warning'
	);

	use HTTP::OAI::DataProvider::Message qw/Debug Warning/;
	new HTTP::OAI::DataProvider::Message (
		Debug =>'&callback',
		Warning=>'&callback'
	);

=cut

=func processSetLibrary

debugging...

=cut

sub _processSetLibrary {
	my $self = shift;

	#debug "Enter salsa_setLibrary";
	my $setLibrary = $self->{setLibrary};

	if ( !$self->{setLibrary} ) {
		die "No setLibrary";
	}

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
	warn "no setLibrary found in Dancer's config file";

}
__PACKAGE__->meta->make_immutable;
1;
