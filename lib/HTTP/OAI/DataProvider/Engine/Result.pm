package HTTP::OAI::DataProvider::Engine::Result;

use Carp qw/croak/;
use HTTP::OAI;
use Encode qw/decode/;    #encoding problem when dealing with data from sqlite
use parent qw(HTTP::OAI::DataProvider::Engine);

use Dancer ':syntax';     #only for debug in development, warnings?
#use XML::SAX::Writer; #still necessary?

=head1 HTTP::OAI::DataProvider::Result

The objective is to make DataProvider::SQLite leaner.

=head1 USAGE

	#INIT
	my $result=new HTTP::OAI::DataProvider::Engine (
		engine=>$engine #necessary, has to have transformer
	);

	#setter and getter for requestURL, will be applied in wrapper, see below
	my $request=$result->requestURL ([$request]);


	#RECORDS
	#write records to result
	$result->saveRecord ($params, $header,$md);

	# makes a record from parts, also transforms md
	$result->addRecord ($record); #prefer saveRecord if possible

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

=cut

=head2 new

see Usage /TODO

=cut

sub new {
	my $class  = shift;
	my $engine = shift;    #only cp what you need from here
	my $result = {};
	bless $result, $class;
	$result->import( $engine, 'requestURL', 'transformer' );

	# transformer
	if ( !$engine->{transformer} ) {
		warning "no transformer. Will not be able to use xslt";
	}

	#init values
	#$result->{records}   = [];    #use $result->countRecords
	#$result->{headCount} = 0;     #use $result->countHeaders
	#$result->{headers} = new HTTP::OAI::ListIdentifiers;
	#$result->{errors}  = [];

	return $result;
}

=head2 my $request=$result->requestURL ([$request]);

Getter and setter. Either expects a $request (complete requestURL including
http:// part and parameters). Or returns it (as string).

requestURL is applied in toGetRecord, toListIdentifiers and to ListRecords to
corresponding HTTP:OAI::Response object.

Note: Naturally, requestURL can change with every request, in contrast to much
of the other stuff like chunk size or Identify info. That's why a separate setter
is convenient.

=cut

sub requestURL {
	my $result  = shift;
	my $request = shift;

	if ($request) {    #setter
		$result->{requestURL} = $request;
	} else {           #getter
		return $result->{requestURL};
	}
}

=head2 $result->addError($code[, $message]);

Adds an HTTP::OAI::Error error to a result object. Test with
	#untested
	if ($result->isError) {
		$provider->err2XML ($result->isError);
	}

=cut

sub addError {
	my $self = shift;
	my $code = shift;    #required
	my $msg  = shift;    #optional

	if ( !$code ) {
		die "addError needs a code";
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

=head2 $result->addHeader ($header);

Adds a header to the result object.

=cut

sub addHeader {
	my $result = shift;
	my $header = shift;
	$result->{posInChunk}++;    #position in chunk
	$result->{headCount}++;     #cursor
	if ( !$header ) {
		croak "Internal Error: Cannot add header, because missing!";
	}

	if ( ref $header ne 'HTTP::OAI::Header' ) {
		croak 'Internal Error: object is not HTTP::OAI::Header';
	}

	#debug "now " . $result->countHeaders . " headers";

	$result->{headers}->identifier($header);

	#every time we add a Header, test if chunk is complete & act accordingly
	$result->chunk;

}

=head2 $result->addRecord ($record);

Adds a record to the result object. Gets called by saveRecord.

=cut

sub addRecord {
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

	#debug ref $record;
	#debug $record->metadata;

	#every time we add a RECORD, test if chunk is complete & act accordingly
	$result->chunk();
}

=head2 my $number=$result->countHeaders;

Return number (scalar) of Headers so far.
=cut

sub countHeaders {
	my $result = shift;
	$result->{headCount} ? return $result->{headCount} : return 0;
}

=head2 my $result->responseCount

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
	} else {
		debug "RecCount" . $result->countRecords;
	}
}

=head2 my $chunkSize=$result->chunkSize;

Return chunk_size if defined or empty. Chunk_size is a config value that
determines how big (number of records per chunk) the chunks are.

=cut

sub chunkSize {
	my $result    = shift;
	my $chunkSize = 100;     #another default, not clean
	if ( $result->{engine}->{chunking} ) {
		$chunkSize = $result->{engine}->{chunking};
	}

	#debug "chunk_size: $chunkSize";
	return $chunkSize;
}


=head2 $result->getType();

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
		} else {
			$chunkRequest->{type} = 'headers';
		}
	}
}

=head2 my $cursor=$result->getCursor;

Return the cursor (needed for resumptionToken). Cursor is the current number of
the first header or record in the chunk and it is absolute meaning that the 2nd
chunk should start on cursor=501 if chunk_size=500. Right?

=cut

sub getCursor {
	my $result       = shift;
	my $chunkRequest = $result->chunkRequest;

	if ( !$chunkRequest->{cursor} ) {
		warning "Cursor not YET initialized!";
	}

	return $chunkRequest->{cursor};
}

=head2 	my $response=$result->getResponse;

Return the content of $result as a HTTP::OAI::Response object. Either
HTTP::OAI::ListIdentifiers or HTTP::OAI::ListRecords, depending on content.

Internally ->getResponse calls toListIdentifiers ro toListRecords, so it
also applies requestURL those. Also applies resumptionToken (rt), if rt is
saved in EOFChunk.

=cut

sub getResponse {
	my $result = shift;
	my $response;

	#debug "Enter getResponse";

	#which type?
	my $cursor       = $result->countHeaders;
	my $chunkRequest = $result->chunkRequest;

	#will the type always be available already?
	if ( $chunkRequest->{type} eq 'records' ) {
		$response = $result->toListRecords;
	} else {
		$response = $result->toListIdentifiers;
	}
	return $response;
}

=head2 my $number_of_records=$result->countRecords;

In scalar context, returns the number of records.

=cut

sub countRecords {
	my $result = shift;
	my $no     = $result->{recCount};
	$no ? return $no : return 0;
}

=head2 my @records=$result->returnRecords;

In list context, returns the record array.

=cut

sub returnRecords {

	#same as countRecords
	my $result = shift;
	return @{ $result->{records} };
}

=head2 $result->saveRecord (params=>$params, header=>$header, md=>$md);

Hand over the parts for the result, construct a record form that and save
it inside $result. Gets called in engine's queryRecord.

=cut

sub saveRecord {
	my $result = shift;
	my %args   = @_;      #contains $params, $header,$md

	#Debug "Enter _saveRecords";

	if ( !$result ) {
		croak "Result is missing";
	}

	if ( ref $result ne 'HTTP::OAI::DataProvider::Result' ) {
		croak "$result is wrong type" . ref $result;
	}

	if ( !$args{params} ) {
		croak "Params are missing";
	}

	if ( !$args{header} ) {
		croak "Header missing";
	}

	#use Data::Dumper qw/Dumper/;
	#debug 'jjjjjjjjjjjjjjjjjj'.Dumper %args;

	#md is optional, a deleted record wd have none
	if ( $args{md} ) {

		#debug "Metadata available";

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
		if ( $result->{engine}->{transformer} ) {
			$dom =
			  $result->{engine}->{transformer}
			  ->toTargetPrefix( $args{params}->{metadataPrefix}, $dom );
		} else {
			warning "Transformer not available";
		}

		#debug $dom->toString;
		$args{metadata} = new HTTP::OAI::Metadata( dom => $dom );
	} else {
		warning "Metadata missing, but that might well be";
	}

	my $record = new HTTP::OAI::Record(%args);

	#debug 'sdsdsdsds' . $record->metadata;
	$result->addRecord($record);
}

=head2 my $getRecord=$result->toGetRecord;

Wraps the record inside the result object in a HTTP::OAI::GetRecord and
returns it. If $result has a requestURL defined, it'll be applied to
GetRecord object.

=cut

sub toGetRecord {
	my $result    = shift;
	my $getRecord = new HTTP::OAI::GetRecord;

	if ( $result->countRecords != 1 ) {
		croak "toGetRecord: count doesn't fit";
	}

	$getRecord->record( $result->returnRecords );

	if ( $result->{requestURL} ) {
		$getRecord->requestURL( $result->requestURL );
	}
	return $getRecord;
}

=head2 my $listRecord=$result->toListRecords;

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

	if ( $result->EOFChunk ) {
		$listRecords->resumptionToken( $result->EOFChunk );
	}

	return $listRecords;
}

=head2 my $listIdentifiers=$result->toListIdentifiers;

Wraps the headers (not records) inside the result object in a
HTTP::OAI::ListIdentifiers and returns it. If $result has a requestURL defined,
it'll be applied to the ListRecord object.

=cut

sub toListIdentifiers {
	my $result          = shift;
	my $listIdentifiers = new HTTP::OAI::ListIdentifiers;

	#not sure if we tested this before
	if ( $result->countHeaders == 0 ) {

		#can break dancer in post position
		croak "toListIdentifiers: count doesn't fit";
	}

	if ( $result->{requestURL} ) {
		$result->{headers}->requestURL( $result->requestURL );
	}

	if ( $result->EOFChunk ) {

		#debug "add resumptionToken". ref $result->EOFChunk;
		$result->{headers}->resumptionToken( $result->EOFChunk );
	}

	return $listIdentifiers->identifier( $result->{headers} );
}

=head2 my @err=$result->isError

Returns a list of HTTP::OAI::Error objects if any.

	if ( $result->isError ) {
		return $self->err2XML($result->isError);
	}

Is _actually_ called in DataProvider.

=cut

sub isError {
	my $result = shift;

	#debug "HTTP::OAI::DataProvider::Result::isError";

	if ( ref $result ne 'HTTP::OAI::DataProvider::Result' ) {
		die "Wrong class in DataProvider::Result isError";
	}

	if ( $result->{errors} ) {

		#Debug 'isError:' . Dumper $self->{errors};
		return @{ $result->{errors} };
	}
}

1;    #HTTP::OAI::DataProvider::Engine::Result

