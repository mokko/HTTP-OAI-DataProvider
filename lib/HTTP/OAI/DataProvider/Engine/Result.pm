package HTTP::OAI::DataProvider::Engine::Result;

# ABSTRACT: Result object for engine

use Carp qw(croak carp);
use HTTP::OAI;
use Encode qw/decode/;    #encoding problem when dealing with data from sqlite
use parent qw(HTTP::OAI::DataProvider::Engine);
use HTTP::OAI::DataProvider::Message qw(warning debug);

#use Dancer ':syntax';     #only for debug in development, warnings?

=head1 OLD SYNOPSIS 

A result is an object that carries the db response before it is transformed to
a HTTP::OAI::Response object.

	#INIT
	my $result=new HTTP::OAI::DataProvider::Engine (%opts);

	#setter and getter for requestURL, will be applied in wrapper, see below
	my $request=$result->requestURL ([$request]);

	#RECORDS
	#write records to result
	$result->saveRecord ($params, $header,$md);

	# makes a record from parts, also transforms md
	$result->_addRecord ($record); #prefer saveRecord if possible

	#simple count
	print $result->countRecords. ' results';

	#access to record data
	my @records=$result->returnRecords;

	#HEADERS
	print $result->countHeaders. 'headers';

	#WRAPPERS
	#return records/headers as a HTTP::OAI::Response
	my $getRecord=$result->toGetRecord;
	my $listIdentifiers=$result->toListIdentifiers;
	my $listRecords=$result->toListRecords;

	#depending on $result will return listIdentifiers or listRecords
	my $response=$result->getResponse

	#CHUNKING
	$bool=$result->chunking; #test if chunking is turned on or off
	$result->chunk; #figures out maxChunkNo and sets
	$result->chunkRequest([bla=>$bla]); #getter & setter for chunkRequest data
	$result->EOFChunk ($rt); #tester, getter & setter for EOFChunk signal

	$result->chunkSize; #getter for chunk_size configuration data
	$result->writeChunk; #write chunk to disk

	#for resumptionToken
	$result->expirationDate; #create an expiration date
	$result->mkToken; #make a token using current micro second

=method my $result=HTTP::OAI::DataProvider::Engine->new (%opts);

	my %opts = (
		requestURL  => $self->{requestURL},
		transformer => $self->{transformer}, #required
		verb        => $params->{verb}, #required
		params      => $params,		#this params should not have a verb

		#for resumptionToken
		chunkSize    => $self->{chunkSize},
		chunkNo      => $chunkDesc->{chunkNo},
		targetPrefix => $chunkDesc->{targetPrefix},
		token        => $chunkDesc->{token},
		total        => $chunkDesc->{total},
	);

$opts{last}
$opts{next}

=cut

sub new {
	my $class  = shift;
	my %args   = @_;
	my $result = \%args;
	bless $result, $class;

	$result->requiredFeatures( 'transformer', 'verb' );

	#init values
	$result->{records}   = [];    #use $result->countRecords
	$result->{headCount} = 0;     #use $result->countHeaders
	$result->{headers} = new HTTP::OAI::ListIdentifiers;
	$result->{errors}  = [];

	return $result;
}

=method my $request=$result->requestURL ([$request]);

Getter and setter. Either expects a $request (complete requestURL including
http:// part and parameters). Or returns it (as string).

requestURL is applied in toGetRecord, toListIdentifiers and to ListRecords to
corresponding HTTP:OAI::Response object.

Note: Naturally, requestURL can change with every request, in contrast to much
of the other stuff like chunk size or Identify info. That's why a separate setter
is convenient.

=cut

#don't think this is necessary anymore, should be done by DataProvider::_output
sub requestURL {
	my $result = shift or carp "Need myself!";
	my $request = shift;

	if ($request) {    #setter
		$result->{requestURL} = $request;
	}
	else {             #getter
		return $result->{requestURL};
	}
}

=method $result->addError($code[, $message]);

Adds an HTTP::OAI::Error error to a result object. Test with
	if ($result->isError) {
		$provider->err2XML ($result->isError);
	}

isError returns 
-in scalar context: true if error is defined and nothing (false) if error is 
 not defined. 
-in list context a list of HTTP::OAI errors, if any

=cut

sub addError {
	my $self   = shift;
	my $code   = shift;    #required
	my $msg    = shift;    #optional
	my @possibleErrors = qw(
	  badArgument
	  badGranularity
	  badResumptionToken
	  badVerb
	  cannotDisseminateFormat
	  idDoesNotExist
	  noRecordsMatch
	  noMetadataFormats
	  noSetHierarchy
	);

	if ( !$code ) {
		carp "addError needs a code";
	}

	if (grep ($_ eq $code,@possibleErrors) == 0) {
		croak "Error code not recognized"; #carp or return?
		return 0; #error
	}

	my %arg;
	$arg{code} = $code;

	if ($msg) {
		$arg{message} = $msg;
	}

	if ($code) {
		push( @{ $self->{errors} }, new HTTP::OAI::Error(%arg) );
	}
}

=method $result->_addHeader ($header);

Adds a header to the result object.

=cut

sub _addHeader {
	my $result = shift;
	my $header = shift;

	#debug "Enter _addHeader";

	$result->{headCount}++;
	if ( !$header ) {
		croak "Internal Error: Cannot add header, because \$header missing!";
	}

	if ( ref $header ne 'HTTP::OAI::Header' ) {
		croak 'Internal Error: object is not HTTP::OAI::Header';
	}

	#debug "now " . $result->countHeaders . " headers";

	$result->{headers}->identifier($header);
}

=method $result->_addRecord ($record);

Adds a record to the result object. Gets called by saveRecord.

=cut

sub _addRecord {
	my $result = shift;
	my $record = shift;
	$result->{recCount}++;      #number of records (cursor)
	$result->{posInChunk}++;    #position in chunk, not cursor

	if ( !$record ) {
		croak "Internal Error: Nothing add";
	}

	if ( ref $record ne 'HTTP::OAI::Record' ) {
		croak 'Internal Error: record is not HTTP::OAI::Record';
	}

	#debug "now" . $result->countRecords . "records";

	push @{ $result->{records} }, $record;
}

=method my $number=$result->countHeaders;

Return number (scalar) of Headers so far.

=cut

sub countHeaders {
	my $result = shift;
	$result->{headCount} ? return $result->{headCount} : return 0;
}

=method my $result->responseCount

Triggers debug output!

=cut

sub responseCount {
	my $result   = shift;
	my $response = shift;

	if ( !$response ) {
		$response = $result->getResponse;
	}
	if ( ref $response eq 'HTTP::OAI::ListIdentifiers' ) {
		debug "HeadCount" . $result->countHeaders;
	}
	else {
		debug "RecCount" . $result->countRecords;
	}
}

=method my $chunkSize=$result->chunkSize;

Return chunk_size if defined or empty. Chunk size is a config value that
determines how big (number of records per chunk) the chunks are.

=cut

sub chunkSize {
	my $result = shift;
	if ( $result->{chunkSize} ) {
		return $result->{chunkSize};
	}
	return ();    #fail
}

=method $result->getType();

getType sets internal type in $result to either headers or records, depending
on content of $result.

=cut

sub getType {
	my $result       = shift;
	my $chunkRequest = $result->chunkRequest;

	if ( !$chunkRequest->{type} ) {

		#TODO: should be numerical operator '>'
		if ( $result->countRecords > 0 ) {
			$chunkRequest->{type} = 'records';
		}
		else {
			$chunkRequest->{type} = 'headers';
		}
	}
}

=method my $response=$result->getResponse;

Return the content of $result as a HTTP::OAI::Response object. Either
HTTP::OAI::ListIdentifiers or HTTP::OAI::ListRecords, depending on content.

Internally ->getResponse calls toListIdentifiers ro toListRecords, so it
also applies requestURL those. Also applies resumptionToken (rt), if rt is
saved in EOFChunk.

TODO: Should also recognize getRecord!


=cut

sub getResponse {
	my $result = shift;

	#debug "Enter getResponse ".$result->{verb};

	if ( $result->{verb} eq 'ListIdentifiers' ) {
		return $result->toListIdentifiers;
	}
	if ( $result->{verb} eq 'GetRecord' ) {
		return $result->toGetRecord;
	}
	if ( $result->{verb} eq 'ListRecords' ) {
		return $result->toListRecords;
	}
	warning "Strange Error!";
}

=method my $number_of_records=$result->countRecords;

In scalar context, returns the number of records.

=cut

sub countRecords {
	my $result = shift;
	my $no     = $result->{recCount};
	$no ? return $no : return 0;
}

=method my @records=$result->returnRecords;

In list context, returns the record array.

=cut

sub returnRecords {

	#same as countRecords
	my $result = shift;
	return @{ $result->{records} };
}

=method $result->save (params=>$params, header=>$header, [md=>$md]);

Expects parts for the result, constructs a result and saves it into the result
object.

This is an abstracted version of saveRecord that automatically does the right
thing whether being passed header or record information. It makes addHeader
and addRecord private methods and saveRecord obsolete.

Gets called in engine's queryChunk.

How do I decide whether something is header or record? At first I thought I
just check whether metadata info is there or not, but this would fail with
deleted records, so now I check for the verb. That means I have to pass the
verb to result->{verb} when result is born.

=cut

sub save {
	my $result = shift;
	my %args   = @_;      #contains params, header, optional: $md

	#debug "Enter save";

	$result->requiredType('HTTP::OAI::DataProvider::Engine::Result');
	$result->requiredFeatures( \%args, 'header' );
	$result->requiredFeatures('params');

	#md is optional, a deleted record wd have none
	if ( $result->{verb} eq 'ListIdentifiers' ) {
		$result->_addHeader( $args{header} );
		return 0;         #success;
	}

	#assume it is either GetRecord or ListRecords

	if ( $args{md} ) {

		#currently md is a string, possibly in a wrong encoding
		$args{md} = decode( "utf8", $args{md} );

		#this line fails on encoding problem
		my $dom = XML::LibXML->load_xml( string => $args{md} );

		#Debug "----- dom's actual encoding: ".$dom->actualEncoding;
		#load $dom from source file works perfectly
		#my $dom = XML::LibXML->load_xml( location =>
		#'/home/Mengel/projects/Salsa_OAI2/data/fs/objId-1305695.mpx' )
		# or return "Salsa Error: Loading xml file failed for strange reason";
		#now md should become appropriate metadata

		my $prefix;
		$result->{params}->{metadataPrefix}
		  ? $prefix = $result->{params}->{metadataPrefix}
		  : $prefix = $result->{targetPrefix};

		if ( !$prefix ) {
			die "still no prefix?";
		}

		#debug "prefix:$prefix-----------------------";

		my $transformer = $result->{transformer};
		if ($transformer) {
			$dom = $transformer->toTargetPrefix( $prefix, $dom );

			#debug "transformed dom" . $dom;
		}
		else {
			warning "Transformer not available";
		}

		#debug $dom->toString;
		$args{metadata} = new HTTP::OAI::Metadata( dom => $dom );
	}
	else {
		warning "metadata not available, but that might well be the case";
	}

	my $record = new HTTP::OAI::Record(%args);
	$result->_addRecord($record);
	return 0;    #success
}

=method my $getRecord=$result->toGetRecord;

Wraps the record inside the result object in a HTTP::OAI::GetRecord and
returns it. If $result has a requestURL defined, it'll be applied to
GetRecord object.

=cut

sub toGetRecord {
	my $result    = shift;
	my $getRecord = new HTTP::OAI::GetRecord;

	if ( $result->countRecords != 1 ) {
		croak "toGetRecord: count doesn't fit" . $result->countRecords;
	}

	$getRecord->record( $result->returnRecords );

	if ( $result->{requestURL} ) {
		$getRecord->requestURL( $result->requestURL );
	}
	return $getRecord;
}

=method my $listRecord=$result->toListRecords;

Wraps the records inside the result object in a HTTP::OAI::ListRecord and
returns it. If $result has a requestURL defined, it'll be applied to the
ListRecord object.

=cut

sub toListRecords {

	my $result      = shift;
	my $listRecords = new HTTP::OAI::ListRecords;

	#debug "Enter toListRecords";

	if ( $result->countRecords == 0 ) {
		croak "records2ListRecords: count doesn't fit";
	}
	$listRecords->record( $result->returnRecords );

	if ( $result->{requestURL} ) {
		$listRecords->requestURL( $result->requestURL );
	}

	if ( !$result->lastChunk ) {
		$listRecords->resumptionToken( $result->_resumptionToken );
	}

	return $listRecords;
}

=head2 $result->_resumptionToken;

Returns the resumptionToken for the result.
This is called in toListIdentifiers and toListRecords. It takes info saved in
$result.

=cut

sub _resumptionToken {
	my $result = shift;

	#debug 'Enter _resumptionToken'.ref $result;

	my $rt = new HTTP::OAI::ResumptionToken(
		completeListSize => $result->{total},

		#todo:cursor currently WRONG!
		cursor          => $result->{chunkNo} * $result->{chunkSize} + 1,
		resumptionToken => $result->{'next'},
	);
	return $rt;
}

=method my $listIdentifiers=$result->toListIdentifiers;

Wraps the headers (not records) inside the result object in a
HTTP::OAI::ListIdentifiers and returns it. If $result has a requestURL defined,
it'll be applied to the ListRecord object.

=cut

sub toListIdentifiers {
	my $result = shift;

	#debug "Enter toListIdentifiers";

	#not sure if we tested this before
	if ( $result->countHeaders == 0 ) {
		croak "toListIdentifiers: count doesn't fit";
	}

	my $listIdentifiers = $result->{headers};

	if ( $result->{requestURL} ) {

		#debug "requestURL:".$result->{requestURL};
		$listIdentifiers->requestURL( $result->requestURL );
	}

	if ( !$result->lastChunk ) {
		$listIdentifiers->resumptionToken( $result->_resumptionToken );
	}
	return $listIdentifiers;
}

=method my @err=$result->isError

Returns a list of HTTP::OAI::Error objects if any.

	if ( $result->isError ) {
		return $self->err2XML($result->isError);
	}

Is _actually_ called in DataProvider.

=cut

sub isError {
	my $result = shift;

	#debug "HTTP::OAI::DataProvider::Result::isError";

	if ( ref $result ne 'HTTP::OAI::DataProvider::Engine::Result' ) {
		die "isError: Wrong class ";
	}

	if ( $result->{errors} ) {
		return @{ $result->{errors} };
	}
	else {
		return ();    #fail
	}
}

=method my $ret=result->lastChunk;

	Returns 1 if this is the last chunk, otherwise empty.

	if ($result->lastChunk)

=cut

sub lastChunk {
	my $result = shift;
	if ( $result->{last} ) {
		return 1;
	}
	return ();
}

1;    #HTTP::OAI::DataProvider::Engine::Result
