package HTTP::OAI::DataProvider::Result;

use Carp qw/croak/;
use HTTP::OAI;


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
	my %args   = shift;
	my $result = {};
	bless $result, $class;
	$result->{records} = [];    #not necessary?

	#Debug "_newResult self". ref $self;
	#Debug "_newResult result". ref $result;

	#copy the transformer in all result objects
	if ( $args{transformer} ) {
		$result->{transformer} = $args{transformer};
	}
	return $result;
}

#should go to HTTP::OAI::DataProvider::Record
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

#
# work on $result->{records}
#

sub countRecords {

	#synonym to returnRecords
	goto &returnRecords;
}

sub returnRecords {

	#same as _countRecords
	my $result = shift;
	return @{ $result->{records} };
}

sub ToGetRecord {
	my $result    = shift;
	my $GetRecord = new HTTP::OAI::GetRecord;

	if ( $result->_countRecords != 1 ) {
		croak "_records2GetRecord: count doesn't fit";
	}

	$GetRecord->record( $result->_returnRecords );

	#Debug "_records2GetRecord: ".$GetRecord;
	return $GetRecord;
}

sub ToListRecords {

	my $result      = shift;
	my $ListRecords = new HTTP::OAI::ListRecords;

	if ( $result->_countRecords == 0 ) {
		croak "_records2ListRecords: count doesn't fit";
	}

	$ListRecords->record( $result->_returnRecords );

	my $i;

	return $ListRecords;
}

sub ToListIdentifiers {

	my $result          = shift;
	my $ListIdentifiers = new HTTP::OAI::ListIdentifiers;

	#not sure if we tested this before
	if ( $result->_countRecords == 0 ) {
		croak "_records2GetRecord: count doesn't fit";
	}

	return $ListIdentifiers->record( $result->_returnRecords );
}

1;    #HTTP::OAI::DataProvider::Result
