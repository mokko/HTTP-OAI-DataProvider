package HTTP::OAI::DataProvider::SQLite;

use warnings;
use strict;
use YAML::Syck qw/Dump LoadFile/;

#use XML::LibXML;
use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_date/;
use Encode qw/decode/;    #encoding problem when dealing with data from sqlite;
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::SAX::Writer;
use Dancer::CommandLine qw/Debug Warning/;
use Carp qw/carp croak/;
use DBI qw(:sql_types);    #new
use DBIx::Connector;
#our $dbh;

#only for debug during development
use Data::Dumper;

#TODO: See if I want to use base or parent?

=head1 NAME

HTTP::OAI::DataProvider::SQLite - A sqlite engine for HTTP::OAI::DataProvider

=head1 SYNOPSIS

1) Create new cache
	use HTTP::OAI::DataProvider::SQLite;
	my $engine=new HTTP::OAI::DataProvider::SQLite (ns_prefix=>$prefix,
		ns_uri=$uri);

	my $err=$engine->digest_single (source=>$xml_fn, mapping=>&mapping);

2) Use cache
	use HTTP::OAI::DataProvider::SQLite;
	my $engine=new HTTP::OAI::DataProvider::SQLite(
		ns_prefix=>$prefix, ns_uri=$uri,
		transformer=>''
		);

	my $header=$engine->findByIdentifier($identifier);
	my $result=$engine->queryHeaders($params);
	my $result=$engine->queryRecords($params);

	TODO

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

Provide a sqlite for HTTP::OAI::DataProvider and abstract all the database
action to store, modify and access header and metadata information.

=head1 TODO

Separate out everything that is not sql-related engine work, so that writing
another engine is MUCH less work. I will probably take out all the stuff to
create results. That looks like another module. Maybe it could be a base
module which the actual engine inherits. That would serve the purpose. Then
it would be
	HTTP::OAI::DataProvider::Engine


=head2 	my $err=$engine->digest_single (source=>$xml_fn, mapping=>&mapping);
=cut

sub digest_single {
	my $self = shift;
	my %args = @_;

	#Debug "Enter digest_single";

	if ( !-e $args{source} ) {
		return "Source file not found";
	}
	my $doc = $self->_loadXML( $args{source} );

	if ( !$doc ) {
		croak "No document";
	}

	if ( !$args{mapping} ) {
		croak "No mapping callback specified";
	}

	#Debug "test: " . $args{mapping};

	my $mapping = $args{mapping};
	no strict "refs";
	while ( my $record = $self->$mapping($doc) ) {
		$self->_storeRecord($record);
	}
	use strict "refs";

}

=head2 my $cache=new HTTP::OAI::DataRepository::SQLite (
	mapping=>'main::mapping',
	ns_prefix=>'mpx',
	ns_uri=>''
);
=cut

sub new {
	my $class = shift;
	my $self  = _new $class;

	if ( !@_ ) {
		croak "Internal Error: Parameters missing";
	}

	my %args = @_;

	if ( !$self ) {
		croak "Internal error: Cannot create myself";
	}

	#Debug "Enter HTTP::OAI::DataProvider::SQLite::_new";

	if ( !$args{dbfile} ) {
		carp "Error: need dbfile";
	}

	#for experiment
	$self->{dbfile} = $args{dbfile};

	if ( $args{ns_uri} ) {
		#Debug "ns_uri" . $args{ns_uri};
		$self->{ns_uri} = $args{ns_uri};
	}

	if ( $args{ns_prefix} ) {
		#Debug "ns_prefix" . $args{ns_prefix};
		$self->{ns_prefix} = $args{ns_prefix};
	}

	#i could check if directory in $dbfile exists; if not provide
	#intelligble warning that path is strange

	$self->_connect_db( $args{dbfile} );
	$self->_init_db();

	#I cannot test earlierstDate since non existant in new db
	#$self->earliestDate();    #just to see if this creates an error;

	return $self;
}

=head1 my $date=$engine->earliestDate();

Maybe your Identify callback wants to call this to get the earliest date for
the Identify verb.

=cut

sub earliestDate {
	my $self = shift;
	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;
	my $sql = qq/SELECT MIN (datestamp) FROM records/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $aref = $sth->fetch;

	if ( !$aref->[0] ) {
		croak "No date";
	}

	#$aref->[0] =~ /(^\d{4}-\d{2}-\d{2})/;
	#datestamp must have the format/length which is specified by granularity
	return $aref->[0];

}

=head2 $engine->granularity();

Returns either "YYYY-MM-DDThh:mm:ssZ" or "YYYY-MM-DD" depending of granularity
of datestamps in the store.

Question is how much trouble I go to check weather all values comply with this
definition?

TODO: Check weather all datestamps comply with format

=cut

sub granularity {

	#Debug "Enter granularity";
	my $self=shift;

	my $long    = 'YYYY-MM-DDThh:mm:ssZ';
	my $short   = 'YYYY-MM-DD';
	my $default = $long;

	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;
	my $sql = q/SELECT datestamp FROM records/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	# alternative is to test each and every record
	# not such a bad idea to do this during Identify
	#	while (my $aref=$sth->fetch) {
	#	}

	my $aref = $sth->fetch;
	if ( !$aref->[0] ) {
		Warning "granuarity cannot find a datestamp and hence assumes $default";
		return $default;
	}

	if ( $aref->[0] =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/ ) {
		return $long;
	}

	if ( $aref->[0] =~ /^\d{4}-\d{2}-\d{2}/ ) {
		return $short;
	}

	Warning "datestamp doesn't match requirements. I assume $short";
}

=head2	$header=$engine->findByIdentifier($identifier)
	Finds and return a specific header (HTTP::OAI::Header) by identifier.

	If no header with this identifier found, this method returns nothing. Who
	had expected otherwise? If called with identifier, should I croak? I guess
	so since it indicates a mistake of the frontend developer. And we want her
	alert!

=cut

sub findByIdentifier {
	my $self       = shift;
	my $identifier = shift;

	#I am not sure if I should croak or keep silent.
	if ( !$identifier ) {
		croak "No identifier specified";
	}

	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;;


	#Debug "Id: $identifier";
	#If I cannot compose a header from the db I have the wrong db scheme
	#TODO: status is missing in db
	#I could do a join and get the setSpecs

	my $sql = q/SELECT datestamp, setSpec FROM records JOIN sets ON
	records.identifier = sets.identifier WHERE records.identifier=?/;

	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute($identifier) or croak $dbh->errstr();
	my $aref = $sth->fetch;

	#there should be exactly one record with that id or none and I will trust
	#my db on that
	#However, I do want to test if I really get a result at all
	if ( $aref->[0] ) {

		my $h = new HTTP::OAI::Header(
			identifier => $identifier,
			datestamp  => $aref->[0]
		);

		#$h->identifier = $identifier;
		#$h->datestamp  = $aref->[0];

		#TODO $h->status=$aref->[1];

		while ( $aref = $sth->fetch ) {
			if ( $aref->[1] ) {
				$h->setSpec( $aref->[1] );
			}
		}
		return $h;
	}
}

=head2 my @setSpecs=$provider->listSets();

Return those setSpecs which are actually used in the store. Expects nothing,
returns an array of setSpecs as string. Called from DataProvider::ListSets.

=cut

sub listSets {
	my $self = shift;
	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;

	#Debug "Enter ListSets";

	my $sql = q/SELECT DISTINCT setSpec FROM sets ORDER BY setSpec ASC/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	#can this be done easier without another setSpec?
	my @setSpecs;
	while ( my $aref = $sth->fetch ) {
		#Debug "listSets:setSpec='$aref->[0]'";
		push( @setSpecs, $aref->[0] );
	}
	return @setSpecs;
}

=head2 $result=$provider->queryHeaders (metadataPrefix=>'x');

Possible paramters are metadataPrefix, from, until and Set. Queries the data
store and returns a HTTP::OAI::DataProvider::SQLite object which contains
errors (in key {errors}) or a HTTP::OAI::ListIdentifiers (in key
{ListIdentifiers}).

TODO: Of course, it returns only those headers which comply with paramaters.

Test for failure:
if ($result->isError) {
	#do this
}

=cut

sub queryHeaders {
	my $self   = shift;
	my $params = shift;

	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;

	#Debug "Enter queryHeaders ($params)";

	my $result = $self->_newResult;

	#i now think they are not necessary
	#$result->_queryChecks($params);

	#if ( $result->isError ) {
	#	return $result;
	#}

	# metadata munging
	my $sql = _querySQL($params);

	#Debug $sql;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $header;
	my $i       = 0;     #count the results to test if none
	my $last_id = '';    #needs to be an empty string
	my $LI = new HTTP::OAI::ListIdentifiers;
	while ( my $aref = $sth->fetch ) {
		$i++;

		if ( $last_id ne $aref->[0] ) {

			#a new item
			$header = new HTTP::OAI::Header;
			$header->identifier( $aref->[0] );
			$header->datestamp( $aref->[1] );
			if ( $aref->[2] ) {
				$header->status('deleted');
			}
		}
		if ( $aref->[3] ) {
			my $set = new HTTP::OAI::Set;

			#TODO: Do I need to expand info from setLibrary?
			#It seems that ListIdentifiers wants to know about setSpecs only
			$set->setSpec( $aref->[3] );
			$header->setSpec($set);
		}
		$last_id = $aref->[0];

		#add header to LI
		$LI->identifier($header);
	}
	#Debug "queryHeaders found $i headers";

	$result->{ListIdentifiers} = $LI;

	# Check result
	if ( $i == 0 ) {
		$result->_addError('noRecordsMatch');
	}

	# Return
	return $result;
}

# seems not to be necessary!
# $result->_queryChecks ($params);
sub _queryChecks {
	my $result = shift;
	my $params = shift;

	if ( !$params ) {
		croak "Internal Error: Params are missing";
	}

	#should already be tested, so only croak
	if ( !$params->{metadataPrefix} ) {

		#Debug Dumper $params;
		croak "metadataPrefix missing!";
	}

	#date format has NOT been tested before
	#a bit unexpected that validation succeeds when it fails, but who cares?
	foreach (qw/until from/) {
		if ( $params->{$_} ) {
			if ( validate_date( $params->{$_} ) ) {
				$result->_addError( 'badArgument',
					"Argument $_ is not a valid date" );
			}
		}
	}
}

=head2 my $result=$engine->queryRecords (identifier=>$identifier,
metadataPrefix=>$prefix);

Like queryHeaders getSingleRecord returns a HTTP::OAI::DataProvider::SQLite
object which contains either
a) one or more records as HTTP::OAI::Records in {@records}.
b) or appropriate error messages (e.g. noRecordMatch).

Apparently, it also transforms to destination format if prefix is not native
format.

OLD
	#check if identifier exists in cache
	my $header = $self->{engine}->findByIdentifier( $params->{identifier} );

=cut

sub queryRecords {
	my $self   = shift;
	my $params = shift;
	my $result = $self->_newResult;

	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;
	#Debug "Enter queryRecords ($params)";

	# check parameters
	# I believe now we don't need that at this point.

	# metadata munging
	my $sql = _querySQL( $params, 'md' );

	#Debug $sql;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $header;
	my $md;
	my $i       = 0;     #count the results to test if none
	my $last_id = '';    #needs to be an empty string

	#this loop is a bit complicated
	#it loops over db rows which contain redundant info (cartesian product)
	#I keep track of last identifiers: if known it is a repetitive row
	#and if a header is already defined, so I can have an action before I
	#start the next header
	while ( my $aref = $sth->fetch ) {
		if ( $last_id ne $aref->[0] ) {
			$i++;        #count distinct identifiers

			if ($header) {

				#a new distinct id where header has already been defined
				#first time on the row which has the 2nd distinct id
				#previous header looks ready

				$result->_saveRecord( $params, $header, $md );
			}

			#on every distinct identifier
			#Debug "result found identifier: " . $aref->[0];
			$header = new HTTP::OAI::Header;
			$header->identifier( $aref->[0] );
			$header->datestamp( $aref->[1] );
			if ( $aref->[2] ) {
				$header->status('deleted');
			}
			if ( $aref->[4] ) {
				$md = $aref->[4];
			}
		}

		#every row
		if ( $aref->[3] ) {

			#wrong: OAI:Set seems to be only for ListSets
			#use header->setSpec instead!
			#my $set = new HTTP::OAI::Set;

			#TODO: Do I need to expand info from setLibrary?
			#$set->setSpec( $aref->[3] );
			$header->setSpec( $aref->[3] );
		}

		$last_id = $aref->[0];
	}

	#if only 1 row it doesn't work, because there is no more iteration
	#pthis accounts for every last distinct identifier, so call it here
	#save the last record
	$result->_saveRecord( $params, $header, $md );

	#Debug "queryRecords found matching $i headers";

	#does not make much of a difference
	#$stylesheet_cache{ $params->{metadataPrefix} } = undef;

	# Check result
	if ( $i == 0 ) {
		$result->_addError('noRecordsMatch');
	}

	#Debug 'queryResults: ' . Dumper $result->{records};    #'@{};

	# Return
	return $result;

}

#should go to HTTP::OAI::DataProvider::Record

=head2 my @err=$result->isError

Returns a list of arrays if any.

	if ( $result->isError ) {
		return $self->err2XML($result->isError);
	}

=cut

sub isError {
	my $self = shift;

	#Debug "bumble";
	if ( exists $self->{errors} ) {

		#Debug 'isError:' . Dumper $self->{errors};
		return @{ $self->{errors} };
	}
}

#
#
#

=head1 Internal Methods - to be called from other inside this module

=cut

#standard constructor
sub _new {
	my $class  = shift;
	my $result = {};
	return ( bless $result, $class );
}

#should go to HTTP::OAI::DataProvider::Record
#copy transformer...
sub _newResult {
	my $self   = shift;
	my $result = _new HTTP::OAI::DataProvider::SQLite;
	$result->{records} = [];    #not necessary?

	#Debug "_newResult self". ref $self;
	#Debug "_newResult result". ref $result;

	#copy the transformer in all result objects
	if ( $self->{transformer} ) {
		$result->{transformer} = $self->{transformer};
	}
	return $result;
}

#adds an error to a result object
# $self->_addError($code[, $message]);
sub _addError {
	my $self = shift;
	my $code = shift;    #required
	my $msg  = shift;    #optional

	if ( !$code ) {
		die "_addError needs a code";
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

#should go to HTTP::OAI::DataProvider::Record
sub _addRecord {
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

sub _connect_db {
	my $self=shift;
	my $dbfile = shift;

	if ( !$dbfile ) {
		croak "_connect_db: No dbfile";
	}

	#Debug "Connecting to $dbfile...";

	$self->{connection} = DBIx::Connector->new(
		"dbi:SQLite:dbname=$dbfile",
		'', '',
		{
			sqlite_unicode => 1,
			RaiseError     => 1
		}
	  ) or die "Problems with DBIx::connector";
}

sub _init_db {
	#Debug "Enter _init_db";
	my $self=shift;
	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;

	if ( !$dbh ) {
		carp "Error: database handle missing";
	}
	$dbh->do("PRAGMA foreign_keys");
	$dbh->do("PRAGMA cache_size = 8000");    #doesn't make a big difference
	                                         #default is 2000

	my $sql = q / CREATE TABLE IF NOT EXISTS sets( 'setSpec' STRING NOT NULL,
			'identifier' TEXT NOT NULL REFERENCES records(identifier) ) /;

	#Debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;

	#TODO: Status not yet implemented
	$sql = q/CREATE TABLE IF NOT EXISTS records (
  		'identifier' TEXT PRIMARY KEY NOT NULL ,
  		'datestamp'  TEXT NOT NULL ,
  		'status'     INTEGER,
  		'native_md'  BLOB)/;

	# -- null or 1
	#Debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;
}

#my $doc=$cache->_loadXML ($file);
sub _loadXML {
	my $self     = shift;
	my $location = shift;

	#Debug "Enter _loadXML ($location)";

	if ( !$location ) {
		croak "Nothing to load";
	}

	my $doc = XML::LibXML->load_xml( location => $location )
	  or croak "Could not load " . $location;

	$doc = _registerNS( $self, $doc );

	if ( !$doc ) {
		croak "Warning: somethings strange with $location of them";
	}
	return $doc;
}

sub _querySQL {
	my $params = shift;
	my $md     = shift;

	my $sql = q/SELECT records.identifier, datestamp, status, setSpec /;

	if ($md) {
		$sql .= q/, native_md /;
	}

	$sql .= q/FROM records JOIN sets ON records.identifier = sets.identifier
	/;

	$sql .= q/ WHERE /;

	if ( $params->{identifier} ) {
		$sql .= qq/records.identifier = '$params->{identifier}' AND /;
	}

	if ( $params->{from} ) {
		$sql .= qq/ datestamp > '$params->{from}' AND /;
	}

	if ( $params->{until} ) {
		$sql .= qq/ datestamp < '$params-> {until}' AND /;
	}

	if ( $params->{set} ) {
		$sql .= qq/setSpec = '$params->{set}' AND /;
	}

	$sql .= q/1=1/;

	#About order: I could add "ORDER BY records.identifier ASC" which gives us
	#strict alphabetical order. Not want is expected. That wdn' t really be a

	#problem, but not nice. Now we have the order we put'em in. Less reliable,
	#but more intuitive. Until it goes wrong.

	#$sql = q/SELECT records.identifier, datestamp, status, setSpec
	#FROM records JOIN sets ON records.identifier = sets.identifier/;

	#Debug $sql;
	return $sql

}

sub _registerNS {
	my $self = shift;
	my $doc  = shift;

	#Debug 'Enter _registerNS';

	if ( $self->{ns_prefix} ) {
		if ( !$self->{ns_uri} ) {
			croak "ns_prefix specified, but ns_uri missing";
		}
		#Debug 'ns: ' . $self->{ns_prefix} . ':' . $self->{ns_uri};

		$doc = XML::LibXML::XPathContext->new($doc);
		$doc->registerNs( $self->{ns_prefix}, $self->{ns_uri} );
	}
	return $doc;
}

#
# work on $result->{records}
#

sub _countRecords {

	#synonym to returnRecords
	goto &_returnRecords;
}

sub _returnRecords {

	#same as _countRecords
	my $result = shift;
	return @{ $result->{records} };
}

sub _records2GetRecord {
	my $result    = shift;
	my $GetRecord = new HTTP::OAI::GetRecord;

	if ( $result->_countRecords != 1 ) {
		croak "_records2GetRecord: count doesn't fit";
	}

	$GetRecord->record( $result->_returnRecords );

	#Debug "_records2GetRecord: ".$GetRecord;
	return $GetRecord;
}

sub _records2ListRecords {

	my $result      = shift;
	my $ListRecords = new HTTP::OAI::ListRecords;

	if ( $result->_countRecords == 0 ) {
		croak "_records2ListRecords: count doesn't fit";
	}

	$ListRecords->record( $result->_returnRecords );

	my $i;

	#while (){
	#	$i++;
	#	Debug "record $i";
	#	$ListRecords->record($_);
	#}

	return $ListRecords;
}

sub _records2ListIdentifiers {

	my $result          = shift;
	my $ListIdentifiers = new HTTP::OAI::ListIdentifiers;

	#not sure if we tested this before
	if ( $result->_countRecords == 0 ) {
		croak "_records2GetRecord: count doesn't fit";
	}

	return $ListIdentifiers->record( $result->_returnRecords );
}

#called in queryRecords to create array with result records
sub _saveRecord {
	my $result = shift;
	my $params = shift;
	my $header = shift;
	my $md     = shift;
	my %params;

	#Debug "Enter _saveRecords";

	if ( !$result ) {
		croak "Result is missing";
	}

	if ( ref $result ne 'HTTP::OAI::DataProvider::SQLite' ) {
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
#my $dom = XML::LibXML->load_xml( location => '/home/Mengel/projects/Salsa_OAI2/data/fs/objId-1305695.mpx' )
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

	$result->_addRecord($record);

	#Debug "save records in \@records. Now count is " . $result->_countRecords;
}

#store record in db
sub _storeRecord {
	my $self   = shift;
	my $record = shift;

	my $header     = $record->header;
	my $md         = $record->metadata;
	my $identifier = $header->identifier;
	my $datestamp  = $header->datestamp;

	my $dbh=$self->{connection}->dbh() or die $DBI::errstr;

	#Debug "Enter _storeRecord";

	if ( !$record ) {
		croak "No record!";
	}

	if ( !$header ) {
		croak "No header!";
	}

	if ( !$md ) {
		croak "No metadata!";
	}

	if ( !$datestamp ) {
		croak "No datestamp!";
	}
	if ( !$identifier ) {
		croak "No identifier!";
	}

	if ( !$dbh ) {
		croak "No database handle!";
	}

	#now I want to add: update only when datestamp equal or newer
	#i.e. correct behavior might be
	#a) insert because rec does not yet exist at all
	#b) update because rec exists and is older
	#c) do nothing because rec exists already and is newer
	#my first idea is to check with a SELECT
	#get datestamp and determine which of the two actions or none
	#have to be taken

	my $check = qq(SELECT datestamp FROM records WHERE identifier = ?);
	my $sth = $dbh->prepare($check) or croak $dbh->errstr();
	$sth->execute($identifier) or croak $dbh->errstr();
	my $datestamp_db = $sth->fetchrow_array;

	#croak $dbh->errstr();

	if ($datestamp_db) {

		#if datestamp, then compare db and source datestamp
		#Debug "datestamp source: $datestamp // datestamp $datestamp_db";
		if ( $datestamp_db le $datestamp ) {
			#Debug "$identifier exists and date equal or newer -> update";
			my $up =
			    q/UPDATE records SET datestamp=?, native_md =? /
			  . q/WHERE identifier=?/;

			#Debug "UPDATE:$up";
			my $sth = $dbh->prepare($up) or croak $dbh->errstr();
			$sth->execute( $datestamp, $md->toString, $identifier )
			  or croak $dbh->errstr();
		}

		#else: db date is older than current one -> NO update
	} else {

		#Debug "$identifier new -> insert";

		#if no datestamp, then no record -> insert one
		#this implies every record MUST have a datestamp!
		my $in =
		  q/INSERT INTO records(identifier, datestamp, native_md, status) /;
		$in .= q/VALUES (?,?,?,?)/;

		#Debug "INSERT:$in";
		my $sth = $dbh->prepare($in) or croak $dbh->errstr();
		my $status;
		$sth->execute( $identifier, $datestamp, $md->toString, $status )
		  or croak $dbh->errstr();
	}

	#Debug "delete Sets for record $identifier";
	my $deleteSets = qq/DELETE FROM sets WHERE identifier=?/;
	$sth = $dbh->prepare($deleteSets) or croak $dbh->errstr();
	$sth->execute($identifier) or croak $dbh->errstr();

	if ( $header->setSpec ) {
		foreach my $set ( $header->setSpec ) {

			#Debug "write new set:" . $set;
			my $addSet =
			  q/INSERT INTO sets (setSpec, identifier) VALUES (?, ?)/;
			$sth = $dbh->prepare($addSet) or croak $dbh->errstr();
			$sth->execute( $set, $identifier ) or croak $dbh->errstr();
		}
	}
}

1;

