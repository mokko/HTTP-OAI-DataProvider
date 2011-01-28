package HTTP::OAI::DataProvider::Result;

use Carp qw/croak/;
use HTTP::OAI;
use Encode qw/decode/;    #encoding problem when dealing with data from sqlite;
use Dancer ':syntax';

=head1

I guess the objective is to make DataProvider::SQLite leaner.

I am not sure if this module should be a parent to SQLite then it might be called
DataProvider::Engine. It might still be called engine.

	my $result=new HTTP::OAI::DataProvider::Engine (transformer=>$transformer);
	$result->addRecord ($record);

	print $result->countRecords. "results".
	my @records=$result->returnRecords;

	my $getRecord=$result->ToGetRecords;
	my $listIdentifiers=$result->ToListIdentifiers;
	my $listRecords=$result->ToListRecords;

=cut

sub new {
	my $class  = shift;
	my %args = @_;
	my $result = {};
	bless $result, $class;
	$result->{records} = [];    #necessary?

	if ( $args{transformer} ) {
		$result->{transformer} = $args{transformer};
	}

	if ( $args{requestURL} ) {
		$result->{requestURL} = $args{requestURL};
	}
	return $result;
}

=head2 my $request=$result->requestURL ([$request]);

Getter and setter. Either expects a $request (complete requestURL including
http:// part and parameters). Or returns it (as string).

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

=head2 $result->addRecord ($record);

Adds a record to the result object.

=cut

sub addRecord {
	my $result = shift;
	my $record = shift;

	if ( !$record ) {
		croak "Internal Error: Nothing add";
	}

	if ( ref $record ne 'HTTP::OAI::Record' ) {

		#Debug ref $record;
		croak 'Internal Error: record is not HTTP::OAI::Record';
	}

	push @{ $result->{records} }, $record;
}

=head2 my $number_of_records=$result->countRecords;

In scalar context, returns the number of records.

=cut

sub countRecords {

	#synonym to returnRecords
	goto &returnRecords;
}

=head2 my @records=$result->returnRecords;

In list context, returns the record array.

=cut

sub returnRecords {

	#same as countRecords
	my $result = shift;
	return @{ $result->{records} };
}


=head2 $result->saveRecord ($params, header,$md);

Hand over the parts for the result, construct a record form that and save
it inside $result.

=cut

#called in queryRecords to create array with result records
sub saveRecord {
	my $result = shift;
	my $params = shift;
	my $header = shift;
	my $md     = shift;
	my %params; #new params

	#Debug "Enter _saveRecords";

	if ( !$result ) {
		croak "Result is missing";
	}

	if ( ref $result ne 'HTTP::OAI::DataProvider::Result' ) {
		croak "$result is wrong type" . ref $result;
	}

	if ( !$params ) {
		croak "Params are missing";
	}

	if ( !$header ) {
		croak "Header missing";
	}

	#md is optional
	#if ( !$md ) {
	#	Debug "Metadata missing, but that might well be";
	#}

	#prepare params to make OAI::Record
	$params{header} = $header;

	if ($md) {

		#Debug "Metadata available";

		#currently md is a string, possibly in a wrong encoding
		$md = decode( "utf8", $md );

		#this line fails on encoding problem
		my $dom = XML::LibXML->load_xml( string => $md );

		#Debug "----- dom's actual encoding: ".$dom->actualEncoding;

		#load $dom from source file works perfectly
		#my $dom = XML::LibXML->load_xml( location =>
		#'/home/Mengel/projects/Salsa_OAI2/data/fs/objId-1305695.mpx' )
		# or return "Salsa Error: Loading xml file failed for strange reason";
		#now md should become appropriate metadata
		if ( $result->{transformer} ) {
			$dom =
			  $result->{transformer}
			  ->toTargetPrefix( $params->{metadataPrefix}, $dom );
		}

		$md = new HTTP::OAI::Metadata( dom => $dom );
		$params{metadata} = $md;
	}

	my $record = new HTTP::OAI::Record(%params);

	$result->addRecord($record);

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

	if ($result->{requestURL}) {
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

	if ( $result->countRecords == 0 ) {
		croak "records2ListRecords: count doesn't fit";
	}

	$listRecords->record( $result->returnRecords );

	if ( $result->{requestURL} ) {
		$listRecords->requestURL( $result->requestURL );
	}
	return $listRecords;
}

=head2 my $listIdentifiers=$result->toListIdentifiers;

Wraps the records inside the result object in a HTTP::OAI::ListIdentifiers and
returns it. If $result has a requestURL defined, it'll be applied to the
ListRecord object.

=cut

sub toListIdentifiers {

	my $result          = shift;
	my $listIdentifiers = new HTTP::OAI::ListIdentifiers;

	#not sure if we tested this before
	if ( $result->countRecords == 0 ) {
		croak "records2GetRecord: count doesn't fit";
	}

	if ( $result->{requestURL} ) {
		$listIdentifiers->requestURL( $result->requestURL );
	}

	return $listIdentifiers->record( $result->returnRecords );
}

=head2 my @err=$result->isError

Returns a list of arrays if any.

	if ( $result->isError ) {
		return $self->err2XML($result->isError);
	}

SEEMS NOT TO BE USED AT THE MOMENT

=cut

sub isError {
	my $result = shift;

	if ( exists $result->{errors} ) {
		#Debug 'isError:' . Dumper $self->{errors};
		return @{ $result->{errors} };
	}
}


1;    #HTTP::OAI::DataProvider::Result

