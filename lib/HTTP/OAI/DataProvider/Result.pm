package HTTP::OAI::DataProvider::Result;

use Carp qw/croak/;
use HTTP::OAI;
use Encode qw/decode/;    #encoding problem when dealing with data from sqlite
use Dancer ':syntax';     #only for debug in development, warnings?
use Time::HiRes qw(gettimeofday);    #to generate unique tokens
use XML::SAX::Writer;

=head1 HTTP::OAI::DataProvider::Result

The objective is to make DataProvider::SQLite leaner.

=head1 USAGE

	#init the object
	my $result=new HTTP::OAI::DataProvider::Engine (
		engine=>$engine #necessary, has to have transformer
		total=>$no_request_results #option (needed for chunking)
	);

	#setter and getter for requestURL, will be applied in wrapper, see below
	my $request=$result->requestURL ([$request]);

	#access records directly
	$result->saveRecord ($params, $header,$md); # makes a record from parts,
		#transforms metadata and adds it to result
	$result->addRecord ($record); #prefer saveRecord if possible

	print $result->countRecords. "results".
	my @records=$result->returnRecords;

	#Wrappers: wrap records in a HTTP::OAI::Response
	#(apply requestURL value if set)
	my $getRecord=$result->toGetRecord;
	my $listIdentifiers=$result->toListIdentifiers;
	my $listRecords=$result->toListRecords;

=cut

sub new {
	my $class  = shift;
	my $engine = shift;
	my $total  = shift;

	my $result = {};
	bless $result, $class;

	$result->{records}   = [];    #use $result->countRecords
	$result->{headCount} = 0;     #use $result->countHeaders
	$result->{headers} = new HTTP::OAI::ListIdentifiers;
	$result->{errors}  = [];

	if ( $engine->{transformer} ) {
		$result->{transformer} = $engine->{transformer};
	} else {
		warning "no transformer. Will not be able to use xslt";
	}

	#resumption settings from engine init/Dancer's config
	if ( $engine->{resumption} ) {
		$result->{resumption} = $engine->{resumption};
		$result->{chunk_dir}  = $engine->{chunk_dir};
	}

	#total no of results for resumptionToken
	if ($total) {
		$result->{total} = $total;
	}

	return $result;
}

=head2 my $request=$result->requestURL ([$request]);

Getter and setter. Either expects a $request (complete requestURL including
http:// part and parameters). Or returns it (as string).

Note: Naturally, requestURL can change with every request, in contrast to much
of the other stuff like chunk size or Identify info. That's why a separate setter
is convenient.

=cut

sub requestURL {
	my $result  = shift;
	my $request = shift;

	if ($request) {
		$result->{requestURL} = $request;
	} else {
		return $result->{requestURL};
	}
}

=head2 $result->addError($code[, $message]);

adds an error to a result object

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
		croak "Internal Error: Nothing add";
	}

	if ( ref $header ne 'HTTP::OAI::Header' ) {
		croak 'Internal Error: object is not HTTP::OAI::Header';
	}

	#debug "now " . $result->countHeaders . " headers";

	$result->{headers}->identifier($header);
	$result->chunk;             #test if chunk complete, act accordingly

}

=head2 $result->addRecord ($record);

Adds a record to the result object.

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
	$result->chunk();
}

=head2 my $number=$result->countHeaders;

Return number (scalar) of Headers so far.
=cut

sub countHeaders {
	my $result = shift;
	$result->{headCount} ? return $result->{headCount} : return 0;
}

=head2 my $bool=$result->chunking;

Returns true if chunking is activated and false if it isn't. Config value.

=cut

sub chunking {
	my $result = shift;
	return 1 if $result->{resumption};
}

=head2 my $chunk_size=$result->chunkSize;

Return chunk_size if defined or empty. Chunk_size is a config value that
determines how big (number of records per chunk) the chunks are.

=cut

sub chunkSize {
	my $result = shift;
	if ( $result->{resumption} ) {
		return $result->{resumption};
	}
}

=head2 $result->chunk()

Gets called in addRecord and addHeader. Saves its outcome into the result
object. Outcome is tested in queryHeader and queryRecord which
return only the first chunk in case chunking is activated.

1. Tests if chunking is on or off, continue only if on
2. compare current record with chunk size, continue if equal
3. create complete chunk
   (since token for next chunk does not exist yet, buffer current chunk
   until next chunk is ready)
3. if end of first chunk, return that
4. if end of further chunks, write them to disk
5. "Return" value: save first chunk in result document and return it
   from queryHeader and queryRecord.
6. Reset current records/headers in result so never more than one chunk
   is assembled.

=cut

sub chunk {
	my $result = shift;

	if ( !$result->chunking ) {
		return ();
	}

	#get number of current result
	my $cursor = $result->countHeaders;
	my $type   = 'headers';
	if ( $result->countRecords gt $cursor ) {
		$cursor = $result->countRecords;
		$type   = 'records';
	}

	if ( !$result->{maxChunkNo} ) {

		#e.g. 2222 total with 500 chunk size: 1, 501, 1001, 1501, 2001
		my $max = $result->{total} / $result->chunkSize;    #max no of chunks
		$result->{maxChunkNo} = sprintf( "%d", $max );      #rounded up to int
		debug 'maxChunkNo:' . $result->{maxChunkNo};
		debug 'total:' . $result->{total};
		debug "type: $type";
	}

	#compare current result with chunk size
	if ( $result->{posInChunk} == $result->chunkSize ) {
		$result->{curChunkNo}++;    #a new chunk is ready
		my $chunk;                  #x headers or records make up a chunk
		debug "curChunk:" . $result->{curChunkNo};
		if ( $type eq 'headers' ) {
			$chunk = $result->toListIdentifiers;
		} else {
			$chunk = $result->toListRecords;
		}

		#current token, first token gets discarded
		my $token = $result->mkToken;

		#mk ResumptionToken object
		#I cannot make the current token here, because I don't have the
		#future token yet, so save it to buffer. (true only the second time)
		if ( $result->{bufferChunk} ) {

			#debug "every but 1st loop";
			#NEW token
			my $rt = new HTTP::OAI::ResumptionToken(
				completeListSize => $result->{total},
				cursor           => $cursor,
				expirationDate   => $result->expirationDate,
				resumptionToken  => $token,
			);

			if ( ref $rt ne 'HTTP::OAI::ResumptionToken' ) {
				die "Wrong object (HTTP::OAI::ResumptionToken)";
			}

			#get buffered chunk
			my $old_chunk = $result->{bufferChunk};

			if ( $result->{maxChunkNo} != $result->{curChunkNo} ) {

			   #attach NEW token to OLD chunk -> now first chunk SHOULD be ready
			   #except:last chunk mustn't have rt!

				$old_chunk->resumptionToken($rt);

				#last chunk: replace response obj with firstChunk
				#do this in toListIdentifiers, toListRecords
			}

			#either save in firstChunk or disk cache
			if ( $result->{curChunkNo} == 2 ) {

				#only on 2nd loop we have the first chunk!
				debug "save first chunk in \$result->{firstChunk}";
				if ( !$old_chunk ) {
					die "Internal Error: no old chunk";
				}
				$result->{firstChunk} = $old_chunk;
			} else {

				#use old token for filename
				$result->write_chunk_to_disk;

				#debug "write chunk to disk";

			}
		}

		#debug "every chunk (including first)";

		#buffer current since no info on future token yet
		$result->{bufferChunk} = $chunk;
		$result->{bufferToken} = $token;

		#reset results
		$result->{records}    = [];    #use $result->countRecords
		$result->{posInChunk} = 0;     #use $result->countHeaders
		$result->{headers} = new HTTP::OAI::ListIdentifiers;

		#still need to write last chunk to disk ...
	}
}

sub write_chunk_to_disk {
	my $result = shift;

	#obviously TODO
	#needs to a variable that is initialized during new Result
	my $path = $result->{chunk_dir} . '/' . $result->{bufferToken};

	debug "write chunk file: $path";

	open( my $fh, ">:encoding(UTF-8)", $path )
	  or die "can't open UTF-8 encoded filename ($path): $!";
	my $w = XML::SAX::Writer->new( Output => $fh );
	$result->{bufferChunk}->set_handler($w);
	$result->{bufferChunk}->generate();

	#debug "Write xml result to temp file to $path";

}

=head2 my $token=$result->mkToken;

Returns an arbitrary token. The only problem is that no token should ever
repeat. I could use the current milisecond. That will never repeat, right?
And it should be unique, right?

=cut

sub mkToken {
	my ( $sec, $msec ) = gettimeofday;
	$sec = time;    #seconds since epoch
	return "$sec$msec";
}

=head2 my $date=$result->expirationDate;

Returns a date 24h in the future from now.

According to OAI spec, expirationDate is optional.

Format is YYYY-MM-DDThh:mm:ssZ

TODO

=cut

sub expirationDate {
	return "2011-12-12T11:11:11Z";
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

=head2 $result->saveRecord ($params, $header,$md);

Hand over the parts for the result, construct a record form that and save
it inside $result.

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

	#md is optional
	#if ( !$md ) {
	#	Debug "Metadata missing, but that might well be";
	#}

	if ( $args{md} ) {

		#Debug "Metadata available";

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
		if ( $result->{transformer} ) {
			$dom =
			  $result->{transformer}
			  ->toTargetPrefix( $args{params}->{metadataPrefix}, $dom );
		}

		$args{md} = new HTTP::OAI::Metadata( dom => $dom );
	}

	$result->addRecord( new HTTP::OAI::Record(%args) );

	#debug "save #"
	#  . $result->countRecords . " of "
	#  . $result->{total}
	#  . " records";

	#Debug "save records in \@records. Now count is " . $result->countRecords;
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

=head2 my $listRecord=$result->toListRecord;

Wraps the records inside the result object in a HTTP::OAI::ListRecord and
returns it. If $result has a requestURL defined, it'll be applied to the
ListRecord object.

=cut

sub toListRecords {

	my $result      = shift;
	my $listRecords = new HTTP::OAI::ListRecords;

	#in chunking mode, return on firstChunk
	if ( $result->{firstChunk} ) {
		debug "Chunking mode firstChunks overwrites current chunk";
		$listRecords = $result->{firstChunk};

	} else {
		#in non-chunking mode
		if ( $result->countRecords == 0 ) {
			croak "records2ListRecords: count doesn't fit";
		}
		$listRecords->record( $result->returnRecords );
	}

	if ( $result->{requestURL} ) {
		$listRecords->requestURL( $result->requestURL );
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

	#in chunking mode, return firstChunk
	if ( $result->{firstChunk} ) {
		debug "headers:Chunking mode firstChunks overwrites lastChunk";
		$result->{ListIdentifiers} = $result->{firstChunk};
		delete $result->{firstChunk};
	}

	#not sure if we tested this before
	if ( $result->countHeaders == 0 ) {
		croak "toListIdentifiers: count doesn't fit";
	}

	if ( $result->{requestURL} ) {
		$listIdentifiers->requestURL( $result->requestURL );
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

1;    #HTTP::OAI::DataProvider::Result

