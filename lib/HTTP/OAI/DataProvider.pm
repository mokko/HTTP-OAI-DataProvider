package HTTP::OAI::DataProvider;

use warnings;
use strict;
use Carp qw/croak carp/;

use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_request/;
use HTTP::OAI::DataProvider::GlobalFormats;
use HTTP::OAI::DataProvider::SetLibrary;
use HTTP::OAI::DataProvider::ChunkCache;
use HTTP::OAI::DataProvider::Transformer;
use HTTP::OAI::DataProvider::SQLite;

#TODO
#use HTTP::OAI::DataProvider::Message qw/Debug Warning/;
use Dancer::CommandLine qw/Debug Warning/;

#for debugging
#use Data::Dumper qw/Dumper/;

=head1 NAME

HTTP::OAI::DataProvider - Simple perl OAI data provider

=head1 VERSION

Version 0.05

=cut

our $VERSION = '0.05';    #with query cache and chunking

=head1 SYNOPSIS

Initialize a data provider (detailed configuration requirements not shown here)

Init for use as provider
    use HTTP::OAI::DataProvider;
    my $provider = HTTP::OAI::DataProvider->new(%options);

Verbs
	my $response=$provider->$verb($params)
	$response=$engine->GetRecord(%params);
	#response is xml ready for print/return

Error checking/TODO
	my $e=$response->isError
	if ($response->isError) {
		#in case of error do this
	}

Debugging
	Currently, I use Dancer::CommandLine. Maybe I should build such a mechanism
	into DataProvider which would also allow to choose a Debug and Warning
	routine via config, something like

    my $provider = HTTP::OAI::DataProvider->new(
    	debug=>'SalsaOAI::Debug',
    	warning=>'SalsaOAI::Warning'
    );

	Debug "message";
	Warning "message";

	TODO
	use HTTP::OAI::DataProvider::Message qw/Debug Warning/;
	new HTTP::OAI::DataProvider::Message (
		Debug =>'&callback',
		Warning=>'&callback'
	);


=head1 OAI DATA PROVIDER FEATURES

supported
- all OAI verbs and all errors in version 2

not supported
- resumptionTokens (working on it)
- hierarchical sets

=head1 COMPONENTS

Currently, the data provider is split in three components which are introduced
in this section: the backend, the frontend and the engine.

BACKEND/FRONTEND

This module attempts to provide a neutral backend for your data provider. It is
not a complete data provider. You will need a simple frontend which handles
HTTP requests and triggers this backend. I use Dancer as frontend, see
Salsa_OAI for an example:

Apart from configuration and callbacks your frontend could look like this:

any [ 'get', 'post' ] => '/oai' => sub {
	if ( my $verb = params->{verb} ) {
		no strict "refs";
		my $response=$provider->$verb( params() );
		return $response->toXML;
	}
};
dance;
true;

OVERVIEW

The engine
-provides a data store,
-a header store and
-the means to digest source data and to
-query both header and data store
-public functions/methods are those which aremeant to be called by the backend.

The backend is
-should not depend on Dancer or any other web framework
-should not depend on a specific metadata format
-should perform most error checks prescribed by the OAI specification.
-public functions/methods are those which are meant to be called from the frontend.

The frontend
-potentially employs a web framework like Dancer
-provides ways to work with specific metadata formats (mappings)
-parses configuration data and hands it over to backend
-includes most or all callbacks

=head1 MORE TERMINOLOGY

I differentiate between SOURCE DATA, DATA STORE and a HEADER STORE.
(For historically reasons, I sometimes refer to the header store as header cache).

"Header" always refers to OAI Headers as specified in the OAI PMH. Sometimes, I
add the letters OAI, sometimes not without indicating any difference in
meaning.

There has to be a way to obtain header information. Typically you will want to
specify rules (using callbacks) which extract OAI header info from the source
data. You might also want to create header information, e.g. when it is
missing, but for simplicity I just call any generation of header data
EXTRACTION.

You could say that the callbacks which extract header data implement some kind
of a mapping. But potentially, you could have many different mappings, so I
avoid this term here. I treat this mapping like configuration data. Therefore,
I locate it in the front end; the backend only has to document these callbacks.

Global MetadataFormats: A metadataFormat is global if any item in the
repository is available in this format. Currently HTTP::OAI::DataProvider
supports only global metadata formats.

=head1 METHODS - INITIALIZATION

=head2 my $provider->new (%options);

Initialize the HTTP::OAI::DataProvider object with the options of your choice.

On failure return nothing; in case this the error is likely to occur during
development and not during runtime it may also croak.

=head3 OPTIONS

List here only options not otherwise explained?

debug=>callback (TODO)
	If a callback is supplied use this callback for debug output

isMetadaFormatSupported=>callback, TODO
	The callback expects a single prefix and returns 1 if true and nothing
	when not supported. Currently only global metadataFormats, i.e. for all
	items in repository. This one seems to be obligatory, so croak when
	missing.

xslt=>'path/to/style.xslt',
	Adds this path to HTTP::OAI::Repsonse objects to modify output in browser.
	See also _init_xslt for more info.

	Except engine information, nothing no option seems to be required and it is
	still uncertain, maybe even unlikely if engine will be option at all.
	(Alternative would be to just to use the engine.)

requestURL
	Overwrite normal requestURL, e.g. when using a reverse proxy cache etc.
	Note that
	a) requestURL specified during new is only the http://domain.com:port
	part (without ? followed by GET params), but that HTTP::OAI treats the
	complete URL as requestURL
	b) badVerb has no URL and no question mark
	c) in modern OAI specification it is actually called request and requestURL

	Currently, requestURL evaporates if Salsa_OAI is run under anything else
	than HTTP::Server::Simple.

warning =>callback (Todo)
	If a callback is supplied use this callback for warning output


=cut

sub new {
	my $class = shift;
	my $self  = shift;    #has Dancer's complete config, not secure
	bless( $self, $class );

	#init chunker
	$self->{chunkCache} = new HTTP::OAI::DataProvider::ChunkCache(
		maxSize => $self->{chunkCacheMaxSize} )
	  or die "Cannot init chunkCache";

	#init global metadata formats
	#small camel is object, big camel is its description
	$self->{globalFormats} = new HTTP::OAI::DataProvider::GlobalFormats;

	my %cnf = %{ $self->{GlobalFormats} };
	foreach my $prefix ( keys %cnf ) {

		#debug " Registering global format $prefix";
		if ( !$cnf{$prefix}{ns_uri} or !$cnf{$prefix}{ns_schema} ) {
			die "GlobalFormat $prefix in yaml configuration incomplete";
		}
		$self->{globalFormats}->register(
			ns_prefix => $prefix,
			ns_uri    => $cnf{$prefix}{ns_uri},
			ns_schema => $cnf{$prefix}{ns_schema},
		);
	}

	#init engine (todo: this is noT properly abstracted)
	$self->{engine} = new HTTP::OAI::DataProvider::SQLite(
		dbfile       => $self->{dbfile},
		chunkCache   => $self->{chunkCache},
		chunkSize    => $self->{chunkSize},
		nativePrefix => $self->{nativePrefix},
		nativeURI    => $self->{native_ns_uri},
		transformer  => new HTTP::OAI::DataProvider::Transformer(
			nativePrefix => $self->{nativePrefix},
			locateXSL    => $self->{locateXSL},
		),
	);
	return $self;
}

=head1 METHODS - VERBS

=head2 my $result=$provider->GetRecord(%params);

Arguments
-identifier (required)
-metadataPrefix (required)

Errors
-badArgument: already tested
-cannotDisseminateFormat: gets checked here
-idDoesNotExist: gets checked here

=cut

sub GetRecord {
	my $self    = shift;
	my $request = shift;

	my $params = _hashref(@_);
	my @errors;

	#Warning 'Enter GetRecord (id:'
	#  . $params->{identifier}
	#  . 'prefix:'
	#  . $params->{metadataPrefix} . ')';

	my $engine        = $self->{engine};
	my $globalFormats = $self->{globalFormats};

	# Error handling

	#only if there is actually an identifier
	if ( $params->{identifier} ) {

		my $header = $engine->findByIdentifier( $params->{identifier} );
		if ( !$header ) {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'idDoesNotExist' ) );
		}
	}

	#somethings utterly wrong, so sense in continuing
	if ( my $error = validate_request( %{$params} ) ) {
		return $self->err2XML($error);
	}

	#check is metadataFormat is supported
	if ( my $e =
		$globalFormats->check_format_supported( $params->{metadataPrefix} ) )
	{
		push @errors, $e;
	}

	if (@errors) {
		return $self->err2XML(@errors);
	}

	# Metadata handling
	my $response = $engine->query( $params, $request );

	#todo: we still have to test if result has any result at all
	#mk sure we don't lose requestURL in Starman
	#$result->requestURL($request);

	# Check result

	#Debug "check results";
	#checkRecordsMatch is now done inside query

	# Return
	return $self->_output($response);

}

=head2 my $response=$provider->Identify();

Simply a callback. It could be located in the frontend and return Identify
information from a configuration file.

Callback should be passed over to HTTP::OAI::DataProvider during
initialization with option Identify, e.g.
	my $provider = HTTP::OAI::DataProvider->new(
		#other options
		#...
		Identify      => 'Salsa_OAI::salsa_Identify',
	);

This method expects HTTP::OAI::Identify object from the callback and will
prompty return a xml string.

=cut

sub Identify {
	my $self = shift;

	#under some servers e.g. Starman HTTP::OAI's auto-requestURL gets confused
	my $requestURL = shift;
	my $params     = _hashref(@_);

	#Debug "Enter Identify ($request)";

	# Metadata munging
	my $obj = new HTTP::OAI::Identify(
		adminEmail        => $self->{adminEmail},
		baseURL           => $self->{baseURL},
		deletedRecord     => $self->{deletedRecord},
		earliestDatestamp => $self->{engine}->earliestDate(),
		granularity       => $self->{engine}->granularity(),
		repositoryName    => $self->{repositoryName},
		requestURL        => $requestURL,
	) or return "Cannot create new HTTP::OAI::Identify";

	# Output
	return $self->_output($obj);
}

=head2 ListMetadataFormats (identifier);

"This verb is used to retrieve the metadata formats available from a
repository. An optional argument restricts the request to the formats available
for a specific item." (the spec)

HTTP::OAI::DataProvider only knows global metadata formats, i.e. it assumes
that every record is available in every format supported by the repository.

ARGUMENTS
-identifier (optional)

ERRORS
-badArgument - in validate_request()
-idDoesNotExist - here
-noMetadataFormats - here

=cut

sub ListMetadataFormats {
	my $self    = shift;
	my $request = shift;

	my $params = _hashref(@_);

	Warning 'Enter ListMetadataFormats';

	#check param syntax, not really necessary
	if ( my $error = validate_request( %{$params} ) ) {
		return $self->err2XML($error);
	}

	#DEBUG
	#	if ( $params->{identifier} ) {
	#		Debug 'with id' . $params->{identifier};
	#	}

	my $engine        = $self->{engine};          #TODO test
	my $globalFormats = $self->{globalFormats};

	#
	# Error handling
	#

	#only if there is actually an identifier
	if ( my $identifier = $params->{identifier} ) {

		my $header = $engine->findByIdentifier($identifier);
		if ( !$header ) {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'idDoesNotExist' ) );
		}
	}

	#Metadata Handling
	my $lmfs = $globalFormats->get_list();

	#$lmfs has requestURL info, so recreate it from $params
	#mk sure we don't lose requestURL in Starman
	$lmfs->requestURL($request);
	my @mdfs = $lmfs->metadataFormat();

	#check if noMetadataFormats
	if ( @mdfs == 0 ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noMetadataFormats' ) );
	}

	#
	# Return
	#

	return $self->_output($lmfs);
}

=head2 my $xml=$provider->ListIdentifiers ($params);

Returns xml as string, either one or multiple errors or a ListIdentifiers verb.

The Spec in my words: This verb is an abbreviated form of ListRecords,
retrieving only headers rather than headers and records. Optional arguments
permit selective harvesting of headers based on set membership and/or
datestamp.

Depending on the repository's support for deletions, a returned header may have
a status attribute of "deleted" if a record matching the arguments specified in
the request has been deleted.

ARGUMENTS
-from (optional, UTCdatetime value)
-until (optional, UTCdatetime value)
-metadataPrefix (required)
-set (optional)
-resumptionToken (exclusive) [NOT IMPLEMENTED!]

ERRORS
-badArgument: already checked in validate_request
-badResumptionToken: here
-cannotDisseminateFormat: here
-noRecordsMatch:here
-noSetHierarchy: here. Can only appear if query has set

LIMITATIONS
By making the metadataPrefix required, the specification suggests that
ListIdentifiers returns different sets of headers depending on which
metadataPrefix is chose. HTTP:OAI::DataProvider assume, however, that there are
only global metadata formats, so it will return the same set for all supported
metadataFormats.

TODO
Hierarchical sets!

=cut

sub ListIdentifiers {
	my $self    = shift;
	my $request = shift;

	my $params = _hashref(@_);
	my @errors;    #stores errors before there is a result object

	#Warning 'Enter ListIdentifiers (prefix:' . $params->{metadataPrefix};
	#Debug 'from:' . $params->{from}   if $params->{from};
	#Debug 'until:' . $params->{until} if $params->{until};
	#Debug 'set:' . $params->{set}     if $params->{set};
	#Debug 'resumption:' . $params->{resumptionToken}
	#  if $params->{resumptionToken};

	my $engine        = $self->{engine};          #provider
	my $globalFormats = $self->{globalFormats};

	# Error handling
	if ( !$engine ) {
		croak "Internal error: Data store missing!";
	}

	if ( !$globalFormats ) {
		croak "Internal error: Formats missing!";
	}

	#check param syntax. Frontend will likely check it, but why not again?
	if ( my $e = validate_request( %{$params} ) ) {
		push @errors, $e;
	}

	if ( $params->{resumptionToken} ) {

		#chunk is response object here!
		my $chunk = $self->chunkExists( $params, $request );

		if ($chunk) {

			#Debug "Get here";
			return $self->_output($chunk);
		} else {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'badResumptionToken' ) );
		}
	}
	if ( my $e =
		$globalFormats->check_format_supported( $params->{metadataPrefix} ) )
	{
		push @errors, $e;    #cannotDisseminateFormat if necessary
	}

	if ( $params->{Set} ) {

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
	my $response = $engine->query( $params, $request );

	if ( !$response ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noRecordsMatch' ) );
	}

	#Debug "RESPONSE:".$response;
	#todo: check if at least one record. On which level?

	# Return
	return $self->_output($response);
}

#this doesn't really make sense, does it?
#where is it called?
sub _badResumptionToken {
	my $self = shift;
	return $self->err2XML(
		new HTTP::OAI::Error( code => 'badResumptionToken' ) );
}

=head2 ListRecords

returns multiple items (headers plus records) at once. In its capacity to
return multiple objects it is similar to the other list verbs
(ListIdentifiers). ListRecord also has the same arguments as ListIdentifier.
In its capacity to return full records (incl. header), ListRecords is similar
to GetRecord.

ARGUMENTS
-from (optional, UTCdatetime value) TODO: Check if it works
-until (optional, UTCdatetime value)  TODO: Check if it works
-metadataPrefix (required unless resumptionToken)
-set (optional)
-resumptionToken (exclusive)

ERRORS
-badArgument: checked for before you get here
-badResumptionToken - TODO
-cannotDisseminateFormat - TODO
-noRecordsMatch - here
-noSetHierarchy - TODO

TODO
-Check if error appears as excepted when non-supported metadataFormat

=cut

sub ListRecords {
	my $self    = shift;
	my $request = shift;

	my $params = _hashref(@_);
	my @errors;

	#Warning 'Enter ListRecords (prefix:' . $params->{metadataPrefix};

	#Debug 'from:' . $params->{from}   if $params->{from};
	#Debug 'until:' . $params->{until} if $params->{until};
	#Debug 'set:' . $params->{set}     if $params->{set};
	#Debug 'resumption:' . $params->{resumptionToken}
	#  if $params->{resumptionToken};

	my $engine        = $self->{engine};
	my $globalFormats = $self->{globalFormats};

	#
	# Error handling
	#

	if ( $params->{resumptionToken} ) {
		my $chunk = $self->chunkExists( $params, $request );
		if ($chunk) {
			return $self->_output($chunk);
		} else {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'badResumptionToken' ) );
		}
	}

	#check is metadataFormat is supported
	if ( my $e =
		$globalFormats->check_format_supported( $params->{metadataPrefix} ) )
	{
		Debug "error in check_format_supported" . $e;
		push @errors, $e;
	}

	if (@errors) {
		return $self->err2XML(@errors);
	}

	#
	# Metadata handling
	#

	my $response = $engine->query( $params, $request );

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

=head2 ListSets

	ARGUMENTS
	resumptionToken (optional)

	ERRORS
	badArgument -> HTTP::OAI::Repository
	badResumptionToken  -> here
	noSetHierarchy --> here

TODO
=cut

sub ListSets {
	my $self    = shift;
	my $request = shift;
	my $params  = _hashref(@_);
	my $engine  = $self->{engine};

	#Warning 'Enter ListSets';

	#
	# Check for errors
	#

	if ( !$engine ) {
		croak "Engine missing!";
	}

	if ( !$self ) {
		croak "Provider missing!";
	}

	#check general param syntax
	if ( my $error = validate_request( %{$params} ) ) {
		return $self->err2XML($error);
	}

	#resumptionTokens not supported
	if ( $params->{resumptionToken} ) {

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

	# Complete naked setSpecs with info from setLibrary
	no strict "refs";    #listSets from Dancer config
	my $listSets = $self->{setLibraryCB}();    #the brackets () are important
	use strict "refs";

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
	} else {
		$listSets = $library->expand(@used_sets);
	}

	#mk sure we don't lose requestURL in Starman
	$listSets->requestURL($request);

	#
	#output fun!
	#
	return $self->_output($listSets);
}

#
#
#

=head1 METHODS - VARIOUS PUBLIC UTILITY FUNCTIONS / METHODS

check error, display error, warning, debug etc.

=head2 my $xml=$provider->err2XML(@obj);

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
				croak "Internal Error: Error has wrong format!";
			}
			$response->errors($_);
			push @errors, $response;
		}

		$self->overwriteRequestURL($response);
		$self->_init_xslt($response);
		return $response->toDOM->toString;
	}
}

#
# PRIVATE STUFF
#

=head1 PRIVATE METHODS

HTTP::OAI::DataProvider is to be used by frontend developers. What is not meant
for them, is private.

=cut

#=head2 $provider->_countResponse($response);
#
#We should be able to count HTTP::OAI::ListIdentifiers and HTTP::OAI::ListRecords
#objects.
#
#=cut
#
#sub _countResponse {
#	my $provider=shift;
#	my $response=shift;
#	my $count=0;
#
#	my $type=ref $response;
#	my $new=new $type;
#
#	while(my $item = $r->next) {
#		$count++;
#		if ($type eq 'HTTP::OAI::ListIdentifers') {
#			$new->identifier ($item)
#		}
#		$new->identifier ($item)
#	}
#
#	return $count;
#}

=head2 my $params=_hashref (@_);

Little thingy that transforms array of parameters to hashref and returns it.

=cut

sub _hashref {
	my %params = @_;
	return \%params;
}

=head2 my $chunk=$self->chunkExists ($params, [$request]);

TODO: should be called getChunkDesc

Tests whether
	a) whether a resumptionToken is in params and
	b) there is a chunkDesc with that token in the cache.

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
	my $request = shift;
	my $token   = $params->{resumptionToken};

	#do NOT check if provider is born with chunking ability!
	#check is request has token
	if ( !$token ) {
		return ();    #how to react if token missing?
	}

	#a) wrong token -> error message
	#b) right token -> return token

	my $chunkCache = $self->{chunkCache};

	if ( !$chunkCache ) {
		die "No chunkCache!";
	}

	#Debug "Query chunkCache for " . $token;

	my $chunkDesc = $self->{chunkCache}->get($token);

	if ( !$chunkDesc ) {

		#ensure that it does return nothing on error! And not 0
		Debug "no chunk description found!";
		return ();
	}

	#chunk is a HTTP::OAI::Response object
	my $response = $self->{engine}->queryChunk( $chunkDesc, $params, $request );
	return $response;
}

=head2 return $self->_output($response);

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
	return $response->toDOM->toString;

	#my $xml;
	#$response->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
	#$response->generate;
	#return $xml;
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
				} else {
					$new = $self->{engine}->{chunkRequest}->{_requestURI};
				}

				$response->requestURL($new);

				#Debug "overwriteRequestURL: "
				#  . $response->requestURL . '->'
				#  . $new;
			} else {

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
	} else {
		Warning "No beautify-xslt loaded!";
	}
}

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

Please use Github.com Issue queue to report bugs
Todo: Link

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTTP::OAI::DataProvider


Look on GitHub.


=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of HTTP::OAI::DataProvider
