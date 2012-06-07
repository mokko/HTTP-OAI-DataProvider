package HTTP::OAI::DataProvider::Engine::Result;

# ABSTRACT: Result object for engine

use Moose;
use namespace::autoclean;
use Carp qw(croak carp);
use HTTP::OAI;
use Encode qw/decode/;    #encoding problem when dealing with data from sqlite

#
# DOUBTFUL!
#not sure if I should inherit from Engine!
#use parent qw(HTTP::OAI::DataProvider::Engine);
use HTTP::OAI::DataProvider::Common qw(Warning Debug);

has 'transformer' => ( isa => 'Object', is => 'ro', required => 1 );
has 'verb'        => ( isa => 'Str',    is => 'ro', required => 1 );

has 'chunkSize'  => ( isa => 'Str',    is => 'ro', required => 1 );
has 'chunkNo'  => ( isa => 'Str',    is => 'ro', required => 1 );
has 'token'  => ( isa => 'Str',    is => 'ro', required => 1 );
has 'targetPrefix'  => ( isa => 'Str',    is => 'ro', required => 1 );
has 'total'  => ( isa => 'Str',    is => 'ro', required => 1 );

has 'next'  => ( isa => 'Str',    is => 'rw', required => 0 );
has 'requestURL'  => ( isa => 'Str',    is => 'rw', required => 0 );

=head1 DESCRIPTIOPN

A result is an object that can carry 
[a) info to carry out a DB query and (should ChunkCache, right?)]
b) the db response before it is transformed to a HTTP::OAI::Response object.
c) it can also carry OAI errors

=head1 OLD SYNOPSIS 

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

	#depending on $result will return listIdentifiers or listRecords
	my $response=$result->getResponse

	#WRAPPERS
	#return records/headers as a HTTP::OAI::Response
	my $getRecord=$result->toGetRecord;
	my $listIdentifiers=$result->toListIdentifiers;
	my $listRecords=$result->toListRecords;

	#CHUNKING
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
		requestURL  => $requestURL, #optional
		transformer => $transformer, #required
		verb        => $verb, #required
		params      => $params,		#this params should not have a verb

		#for resumptionToken
		chunkSize    => $chunkSize,
		chunkNo      => $chunkNo,
		targetPrefix => $targetPrefix,
		token        => $token,
		total        => $total,
	);

#$opts{last}
#$opts{next}

=cut

sub BUILD {
	my $self = shift or carp "Need myself!";

	#init values
	$self->{records}   = [];    #use $result->countRecords
	$self->{headCount} = 0;     #use $result->countHeaders
	$self->{headers} = new HTTP::OAI::ListIdentifiers;
	$self->{errors}  = [];

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
#sub requestURL {
#	my $result = shift or carp "Need myself!";
#	my $request = shift;
#
#	if ($request) {    #setter
#		$result->{requestURL} = $request;
#	}
#	else {             #getter
#		return $result->{requestURL};
#	}
#}

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
	my $self           = shift;
	my $code           = shift;    #required
	my $msg            = shift;    #optional
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

	if ( grep ( $_ eq $code, @possibleErrors ) == 0 ) {
		croak "Error code not recognized";    #carp or return?
		return 0;                             #error
	}

	my %arg;
	$arg{code} = $code;

	if ($msg) {
		$arg{message} = $msg;
	}

	push( @{ $self->{errors} }, new HTTP::OAI::Error(%arg) );
}

=method $result->_addHeader ($header);

Adds a header to the result object.

=cut

sub _addHeader {
	my $result = shift;
	my $header = shift;

	#Debug "Enter _addHeader";

	$result->{headCount}++;
	if ( !$header ) {
		croak "Internal Error: Cannot add header, because \$header missing!";
	}

	if ( ref $header ne 'HTTP::OAI::Header' ) {
		croak 'Internal Error: object is not HTTP::OAI::Header';
	}

	#Debug "now " . $result->countHeaders . " headers";

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

	#Debug "now" . $result->countRecords . "records";

	push @{ $result->{records} }, $record;
}

=method my $number=$result->countHeaders;

Return number (scalar) of Headers so far.

=cut

sub countHeaders {
	my $result = shift;
	$result->{headCount} ? return $result->{headCount} : return 0;
}

=method my $result->_responseCount

Similar to countHeaders, but triggers Debug output!

=cut

sub _responseCount {
	my $result   = shift;
	my $response = shift;

	if ( !$response ) {
		$response = $result->getResponse;
	}
	if ( ref $response eq 'HTTP::OAI::ListIdentifiers' ) {
		Debug "HeadCount" . $result->countHeaders;
	}
	else {
		Debug "RecCount" . $result->countRecords;
	}
}

=method my $chunkSize=$result->chunkSize;

Return chunk_size if defined or empty. Chunk size is a config value that
determines how big (number of records per chunk) the chunks are.

=cut

#sub chunkSize {
#	my $result = shift;
#	if ( $result->{chunkSize} ) {
#		return $result->{chunkSize};
#	}
#	return ();    #fail
#}

=method $result->getType();

getType sets internal type in $result to either headers or records, depending
on content of $result.

TODO:
-This is weird. It looks like it should also return the value;
-There should also be an undef state
=cut

#sub getType {
#	my $result       = shift or die "Wrong!";
#
#	if ( !$result->{type} ) {
#		if ( $result->countRecords > 0 ) {
#			$chunkRequest->{type} = 'records';
#		}
#		else {
#			$chunkRequest->{type} = 'headers';
#		}
#	}
#	#return $result->{type};
#}

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

	#Debug "Enter getResponse ".$result->{verb};

	if ( $result->{verb} eq 'ListIdentifiers' ) {
		return $result->toListIdentifiers;
	}
	if ( $result->{verb} eq 'GetRecord' ) {
		return $result->toGetRecord;
	}
	if ( $result->{verb} eq 'ListRecords' ) {
		return $result->toListRecords;
	}
	Warning "Strange Error!";
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
thing whether being passed header or record information. It makes _addHeader
and _addRecord private methods.

Gets called in engine's queryChunk.

How do I decide whether something is a header or record? At first I thought I
just check whether metadata info is there or not, but this fails in case of
deleted records, so now I check for the verb. That means I have to pass the
verb to result->{verb} when result is born.

=cut

sub save {
	my $result = shift or carp "Need myself!";
	my %args = @_;    #contains params, header, optional: $md

	croak "no header" if ( !$args{header} );
	croak "no params" if ( !$args{params} );

	#md is optional, a deleted record wd have none
	if ( $result->{verb} eq 'ListIdentifiers' ) {
		$result->_addHeader( $args{header} );
		return 1;     #success;
	}

	#assume it is either GetRecord or ListRecords

	if ( $args{md} ) {

		#i believe encoding issue is fixed now
		$args{md} = decode( "utf8", $args{md} );
		my $dom = XML::LibXML->load_xml( string => $args{md} );

		my $prefix = $result->targetPrefix or croak "still no prefix?";
		#Debug "prefix:$prefix-----------------------";

		my $transformer = $result->{transformer};
		if ($transformer) {
			$dom = $transformer->toTargetPrefix( $prefix, $dom );

			#Debug "transformed dom" . $dom;
		}
		else {
			Warning "Transformer not available";
		}

		#Debug $dom->toString;
		$args{metadata} = new HTTP::OAI::Metadata( dom => $dom );
	}
	else {
		Warning "metadata not available, but that might well be the case";
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

	#Debug "Enter toListRecords";

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

	#Debug 'Enter _resumptionToken'.ref $result;

	#print ":::::chunkNo:$result->{chunkNo}\n";
	#print ":::::chunkSize:$result->{chunkSize}\n";

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

	#Debug "Enter toListIdentifiers";

	#not sure if we tested this before
	if ( $result->countHeaders == 0 ) {
		croak "toListIdentifiers: count doesn't fit";
	}

	my $listIdentifiers = $result->{headers};

	if ( $result->{requestURL} ) {

		#Debug "requestURL:".$result->{requestURL};
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

	#Debug "HTTP::OAI::DataProvider::Result::isError";

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
__PACKAGE__->meta->make_immutable;
1;
