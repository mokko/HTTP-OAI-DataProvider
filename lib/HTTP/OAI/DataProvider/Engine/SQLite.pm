package HTTP::OAI::DataProvider::Engine::SQLite;

# ABSTRACT: A simple and fairly generic SQLite engine for HTTP::OAI::DataProvider

use warnings;
use strict;
use Moose::Role;

#use namespace::autoclean;
use Carp qw(carp croak confess);
use DBI qw(:sql_types);    #new
use DBIx::Connector;
use XML::LibXML;
use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_date/;
use HTTP::OAI::DataProvider::Engine::Result;
use HTTP::OAI::DataProvider::ChunkCache;
use HTTP::OAI::DataProvider::Common qw/Debug Warning/;
use HTTP::OAI::DataProvider::Transformer;
with 'HTTP::OAI::DataProvider::Engine::Interface';

=head1 SYNOPSIS
	use HTTP::OAI::DataProvider::SQLite;

	#1) initialize (todo: update options)
		my $engine=new HTTP::OAI::DataProvider::SQLite (
			ns_prefix=>$prefix,
			ns_uri=$uri
		);

	#2) Use query engine

		my $header=$engine->findByIdentifier($identifier);           #result is 		
		my $result=$engine->query($params);          #DP::Engine::Result object
		my $result=$engine->queryHeaders($params);
		my $result=$engine->queryChunk($params);

	#3) Error

	#4) Other stuff
		init(); #gets called from Engine->BUILD;
		my $grany=$engine->granularity();
		my $earliestDate=$engine->earliestDate();

	#inherits additional methods from L<DP::Engine::Interface>,

=head1 DESCRIPTION

Provides about the simplest database backend imaginable for 
HTTP::OAI::DataProvider using SQLite. Modifies and accesses header and metadata
information.

HTTP::OAI::DataProvider::Engine consumes
 HTTP::OAI::DataProvider::Engine::SQLite consumes
  HTTP::OAI::DataProvider::Engine::Interface

=method my $cache=HTTP::OAI::DataProvider::Engine::SQLite->new (@args);

TODO: params

=method my $response=$engine->queryChunk($chunkDescription);

Expects a chunkDescription and outputs xml string response fit for output.

In the meantime it queries the db, parses the answer in a result
object.

A chunk descrition is basically an SQL statement and some other contextual info
in an HTTP::OAI::DataProvider::ChunkCache::ChunkDescription. 

[gets called in queryChunk and in chunkExist]

=cut

sub queryChunk {
	my $self      = shift or croak "Need myself!";
	my $chunkDesc = shift or croak "Need chunkDesc!";
	my $params    = shift or croak "Need params!";

	#Debug "Enter queryChunk";
	#Debug "chunkDesc->chunkNo".$chunkDesc->chunkNo."\n";
	#Debug "recordsPerChunk".$self->{chunkCache}{recordsPerChunk}."\n";

	my %opts = (
		transformer => $self->{transformer},
		verb        => $params->{verb},
		params      => $params,

		#for resumptionToken
		chunkSize    => $self->{chunkCache}{recordsPerChunk},
		chunkNo      => $chunkDesc->chunkNo,
		targetPrefix => $chunkDesc->targetPrefix, 
		token        => $chunkDesc->token,
		total        => $chunkDesc->total,
	);

	#last chunk has no next
	if ( $chunkDesc->next ) {
		$opts{'next'} = $chunkDesc->next;
	}
	else {
		Debug "queryChunk: this is the last chunk!";
		$opts{'last'} = 1;
	}

	my $result = new HTTP::OAI::DataProvider::Engine::Result(%opts);

	#should copy all of the requestURL
	
	#SQL
	my $dbh = $self->{connection}->dbh()       or croak $DBI::errstr;
	my $sth = $dbh->prepare( $chunkDesc->sql ) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	#Debug "chunkDesc SQL $chunkDesc->{sql}";

	my $header;
	my $md;
	my $i       = 0;     #count the results to test if none
	my $last_id = '';    #needs to be an empty string

	#loop over db rows which contain redundant info (cartesian product)
	#I keep track of identifiers: if known it is a repetitive row
	#if header is already defined, have action before starting next header
	while ( my $aref = $sth->fetch ) {

		#$aref->[0] has identifier
		if ( $last_id ne $aref->[0] ) {
			$i++;        #count distinct identifiers
			if ($header) {

				#a new distinct id where header has already been defined
				#first time on the row which has the 2nd distinct id
				#i.e. previous header should be ready for storing it away
				$result->save(
					header => $header,
					md     => $md,
					params => $params,    #doesn't it need params?
				);

				#Debug "md".$md;
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
				$md =  $aref->[4];
				#Debug "GET HERE $md";
			}
			else {

				#not all records also have md, e.g. deleted records
				$md = '';
			}
		}

		#every row
		if ( $aref->[3] ) {
			$header->setSpec( $aref->[3] );
		}

		$last_id = $aref->[0];
	}

	#save the last record;	get here if only one record!
	$result->save(
		header => $header,
		md     => $md,
		params => $params,    #doesn't it need params?
	);

	# Check result
	if ( $result->isError ) {
		return $self->err2XML( $result->isError );
	}

	return $result->getResponse;
}

=head2 my $date=$engine->earliestDate();

Returns the earliest timestamp in datastore.
Defaults to '1970-01-01T01:01:01Z' if db is empty.

gets called in DP::identify.

=cut

sub earliestDate {
	my $self = shift;
	my $dbh  = $self->{connection}->dbh() or die $DBI::errstr;
	my $sql  = qq/SELECT MIN (datestamp) FROM records/;
	my $sth  = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $aref = $sth->fetch;

	if ( !$aref->[0] ) {
		return '1970-01-01T01:01:01Z';
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

TODO: Check whether all datestamps comply with format

=cut

sub granularity {

	#Debug "Enter granularity";
	my $self = shift;

	my $long    = 'YYYY-MM-DDThh:mm:ssZ';
	my $short   = 'YYYY-MM-DD';
	my $default = $long;

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
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

	If no header with this identifier found, nothing is returned. 

=cut

sub findByIdentifier {
	my $self       = shift or croak "Need myself";
	my $identifier = shift or croak "No identifier specified";

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

	#Debug "Id: $identifier";
	#If I cannot compose a header from the db I have the wrong db scheme
	#TODO: status is missing in db
	#I could do a join and get the setSpecs

	my $sql = q/SELECT datestamp, setSpec FROM records JOIN sets ON
	records.identifier = sets.identifier WHERE records.identifier=?/;

	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();

	#print "$sql ($identifier)\n";
	$sth->execute($identifier) or croak $dbh->errstr();
	my $aref = $sth->fetchall_arrayref or carp "difficult fetch";
	if ( $sth->err ) {
		carp "DBI error:" . $sth->err;
	}

	#there should be exactly one record with that id or none and I will trust
	#my db on that
	#However, I do want to test if I really get a result at all
	if ( $aref->[0] ) {
		my $h = new HTTP::OAI::Header(
			identifier => $identifier,
			datestamp  => $aref->[0],
		);

		#TODO $h->status=$aref->[1];

		while ( $aref = $sth->fetch ) {
			if ( $aref->[1] ) {
				$h->setSpec( $aref->[1] );
			}
		}
		return $h;
	}

	return;    #failure
}

=method my @setSpecs=$provider->listSets();

Return those setSpecs which are actually used in the store. Expects nothing,
returns an array of setSpecs as string. Called from DataProvider::ListSets.

=cut

sub listSets {
	my $self = shift or croak "Need myself";
	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

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

=head2 my $i=$self->parseHeaders ($result, $sth);

Expects an empty result object and a statement handle. Returns number of
records parsed. This is the loop that essentially turns queryHeaders into
HTTP::OAI::Headers.

Chunking:
Among others its loop contains a condition to break the loop if chunking is
activated and the first chunk is completed. To access the remaining chunks we
will re-enter this loop at a later point in time.

=cut

=method init

was initChunkCache()

Would this method better be in DP::Engine::SQLite. Does it make much of a 
difference? DP::Engine inherits from the engine, DP:Engine 
needs to initialize the chunkCache anyways. Of course, it would be easy to
require initChunkCache in Interface and then overwrite it if another db 
implementation doesn't need it.

Takes input from $self->{chunkCache} and writes output (object) in 
$self->{ChunkCache}.

=cut

sub init {
	my $self = shift or croak "Need myself!";

	$self->{ChunkCache} =
	     new HTTP::OAI::DataProvider::ChunkCache( maxSize => $self->{chunkCache}{maxChunks} )
	  or croak "Cannot init chunkCache";

	$self->_initDB();
}

=head2 my $first=$self->planChunking($params);

Counts the results for this request to split the response in chunks if
necessary, e.g. 50 records per page. From the numbers it creates all chunk
descriptions for this request and saves them in chunkCache.

A chunkDescription has an sql statement and other contextual info to to write
the chunk (one page of results).

Expects the params hashref. Returns the first chunk description or nothing.
(Saves the remaining chunk descriptions in chunkCache.)

=cut

sub planChunking {
	my $self   = shift;
	my $params = shift;

	#For getRecord we dont NEED to make numbers, but why not...
	my ( $total, $maxChunkNo ) = $self->_mk_numbers($params);

	Debug "planChunking: total records:$total, maxChunkNo:$maxChunkNo\n";

	return if ( $total == 0 );    #empty database?

	my $first;
	my $chunkNo      = 1;
	my $currentToken = $self->mkToken();
	my $chunkCache   = $self->{ChunkCache}; #object
	my $chunkSize    = $self->{chunkCache}->{recordsPerChunk};

	#create all chunkDescriptions in chunkCache
	while ( $chunkNo <= $maxChunkNo ) {
		my $offset = ( $chunkNo - 1 ) * $chunkSize;    #or with +1?
		     #Debug "OFFSET: $offset CHUNKSIZE: $chunkSize";
		my $sql = $self->_querySQL(
			limit  => $chunkSize,
			offset => $offset,
			params => $params,
		);

		my $chunk = new HTTP::OAI::DataProvider::ChunkCache::Description(
			chunkNo      => $chunkNo,
			maxChunkNo   => $maxChunkNo,
			sql          => $sql,
			targetPrefix => $params->{metadataPrefix},
			token        => $currentToken,
			total        => $total
		);

		#the last chunk has no resumption token
		my $nextToken = $self->mkToken();
		if ( $chunkNo < $maxChunkNo ) {
			$chunk->{'next'} = $nextToken;
		}

		#Debug "planChunking: chunkNo:$chunkNo, token:$currentToken"
		#  . ", next:$nextToken, offset: $offset, limit ";

		# LOOP stuff: prepare for next loop
		$chunkNo++;    #now it's safe to increase
		$currentToken = $nextToken;

		#don't write the 1st chunk into cache, keep it in $first instead
		$first ? $chunkCache->add($chunk) : $first = $chunk;
	}

	#Debug "planChunking RESULT".$self->{chunkCache}->count;
	return $first;
}

###
### INTERNAL STUFF - STUFF SPECIFIC TO THiS SQLITE IMPLEMENTATION
###

=head1 Internal Methods 

They are meant to be called from other methods inside this module. They are
relevant for the author of this SQLite implementation, but not to its user.

=head2 my $sql=$self->_querySQL ($params,$limit, $offset);

Returns the sql for the query (includes metadata for GetRecord and
ListRecords).

Used in planChunking. Since it is only called from inside this package I 
consider it private.

=cut

sub _querySQL {
	my $self = shift;
	my %args = @_;

	my $params = $args{params} or croak "Need params";
	my $limit  = $args{limit}  or croak "Need limit";
	my $offset = $args{offset};    #or would croak on 0

	if ( !defined $offset ) { croak "offset missing"; }

	#Debug "OFFSET: $offset LIMIT: $limit";
	#md becomes modifier with values md and count?
	# SELECT COUNT records.identifier FROM records WHERE
	# records.identifier = ? AND
	# datestamp > ? AND
	# datestamp < ? AND
	# setSpec = ?

	my $sql = q/SELECT records.identifier, datestamp, status, setSpec /;

	if (   $params->{verb} eq 'GetRecord'
		or $params->{verb} eq 'ListRecords' )
	{
		$sql .= q/, native_md /;
	}

	$sql .= q/FROM records LEFT JOIN sets ON records.identifier =
	sets.identifier WHERE /;

	if ( $params->{identifier} ) {
		$sql .= qq/records.identifier = '$params->{identifier}' AND /;
	}

	if ( $params->{'from'} ) {
		$sql .= qq/ datestamp > '$params->{'from'}' AND /;
	}

	if ( $params->{'until'} ) {
		$sql .= qq/ datestamp < '$params->{'until'}' AND /;
	}

	if ( $params->{set} ) {
		$sql .= qq/setSpec = '$params->{'set'}' AND /;
	}

	$sql .= qq/ 1=1 LIMIT $limit OFFSET $offset/;

	#About order: I could add "ORDER BY records.identifier ASC" which gives us
	#strict alphabetical order. Not want is expected. That wdn' t really be a
	#problem, but not nice. Now we have the order we put'em in. Less reliable,
	#but more intuitive. Until it goes wrong.

	#$sql = q/SELECT records.identifier, datestamp, status, setSpec
	#FROM records JOIN sets ON records.identifier = sets.identifier/;

	#Debug $sql;
	return $sql

}

=head2 my $connection=_connectDB();

Connects to database and saves DBIx::Connector object in 
	$self->{connection} 

Takes connection info from $self->dbfile and sets database handel in 
$self->connector.

Is now called from initDB. 

=cut

sub _connectDB {
	my $self = shift;
	my $dbfile = $self->dbfile or croak "Need dbfile!";

	#db may be missing if not yet initialized
	if ( !$self->valFileExists($dbfile) ) {
		Warning 'dbfile missing';
	}

	$self->{connection} = DBIx::Connector->new(
		"dbi:SQLite:dbname=$dbfile",
		'', '',
		{
			sqlite_unicode => 1,
			RaiseError     => 1
		}
	) or $self->{error} = "Problems with DBIx::connector";

	if ( !$self->{connection} ) {
		croak 'connection problem';
		$self->{error}='No connection';
		return;    #error
	}
	return 1;      #success
}

=head2 my $count=$self->_countTotals ($params);

For chunking I need to know the total number of results (headers or records)
before I start chunking. This method performs a query and returns that number.

=cut

sub _countTotals {
	my $self   = shift;    #an engine, SQLite object
	my $params = shift;

	my $sql = $self->_queryCount($params);
	Debug "_countTotals: $sql";
	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
	my $sth = $dbh->prepare($sql)        or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $aref = $sth->fetch;

	if ( !$aref->[0] ) {
		return 0;
	}

	#Debug "_____countTotals: $aref->[0]";

	#todo: ensure that it is integer!
	return $aref->[0];
}

=method $self->_initDB()

Expects nothing and returns nothing (via the method call and return value). 
Instead, it takes a database handle from $self->{connection}, checks if 
database schema exists and creates it if it doesn't.

Schema has only two tables
table:sets with columns 
: setSpec
: identifier (expects the OAI identifier)
table:records with columns
: identifier (expects the OAI identifier)
: datestamp (either in small or long format)
: status (might have string 'deleted')
: native_md (xml for one record)

TODO: currently I mix croaking and error messages. Decide what you want!

=cut

sub _initDB {
	my $self = shift;
	$self->_connectDB or croak "Connecting problems";
	my $dbh = $self->{connection}->dbh() or croak $DBI::errstr;

	if ( !$dbh ) {
		$self->{error} = "Error: database handle missing";
		return;
	}

	#not sure about foreign keys
	$dbh->do("PRAGMA foreign_keys = OFF");

	#doesn't seem to make a big difference; default is 2000
	$dbh->do("PRAGMA cache_size = 8000");

	my $sql = q / CREATE TABLE IF NOT EXISTS sets( 'setSpec' STRING NOT NULL,
			'identifier' TEXT NOT NULL REFERENCES records(identifier) ) /;

	#Debug $sql. "\n";
	$dbh->do($sql) or carp $dbh->errstr;

	#TODO: Status not yet implemented
	$sql = q/CREATE TABLE IF NOT EXISTS records (
  		'identifier' TEXT PRIMARY KEY NOT NULL ,
  		'datestamp'  TEXT NOT NULL ,
  		'status'     INTEGER,
  		'native_md'  BLOB)/;

	# -- null or 1
	#Debug $sql. "\n";
	$dbh->do($sql) or carp $dbh->errstr;

}

=method $engine->storeRecord($record);

store record in db

=cut

sub storeRecord {
	my $self   = shift or croak "Need myself";
	my $record = shift or croak "Need record";

	#Debug "Enter _storeRecord $record";
	#check if complete
	my $header = $record->header or croak "No header";
	$record->metadata   or croak "No metadata";
	$header->identifier or croak "No identifier";
	$header->datestamp  or croak "No datestamp";

	#now I want to add: update only when datestamp equal or newer

	my $datestamp_db = $self->_datestampDB($record);

	#croak $dbh->errstr();

	if ($datestamp_db) {

		#if datestamp, then compare db and source datestamp
		#Debug "datestamp source: $datestamp // datestamp $datestamp_db";
		if ( $datestamp_db le $header->datestamp ) {

			Debug
			  "$header->identifier exists and date equal or newer -> update";
			$self->_updateRecord($record) or croak "should be return";
		}
	}
	else {

		#Debug "$identifier new -> insert";
		$self->_insertRecord($record) or croak "should be return";

	}
	$self->_updateSets($record) or croak "should be return";
	return 1;    #success
}

=method my ( $total, $maxChunkNo ) =$self->_mk_numbers($params);

Expects the params as hashRef (todo: turn into hash). Returns
two numbers: The total amount of results and the total number of 
chunks.

Gets called in planChunking.

[This is not database specific. Could go elsewhere if there is more
chunking!]

=cut

sub _mk_numbers {
	my $self       = shift;
	my $params     = shift;
	my $total      = $self->_countTotals($params);
	my $chunkCache = $self->chunkCache;

	#use Data::Dumper qw(Dumper);
	#print Dumper $chunkCache;
	#print "........................test $total/"
	#  . $chunkCache->{recordsPerChunk} . "\n";

	#e.g. 2222 total with 500 chunk size: 1, 501, 1001, 1501, 2001
	my $max = ( $total / $chunkCache->{recordsPerChunk} ) + 1; #max no of chunks
	return $total, sprintf( "%d", $max );    #rounded up to int
}

#sql for count request
sub _queryCount {
	my $self   = shift;
	my $params = shift;

	#so far we were thinking in chunks numbered in real and unique records
	#but now we apply LIMIT and OFFSET to cartesian product, so we should count
	#the cartesian product! That can result in chunks which number
	#significantly less records than the chunkSize if many sets are applied to
	#one record. I don't think this is a real problem, but we should not forget
	#that. Anyway, we remove DISTINCT from this query.
	#
	#records may have no set, but should still be counted, so this has to be a
	#left join
	my $sql = q/SELECT COUNT (records.identifier) FROM /;
	$sql .= q/records LEFT JOIN sets ON records.identifier = sets.identifier
	WHERE /;

	if ( $params->{identifier} ) {
		$sql .= qq/records.identifier = '$params->{identifier}' AND /;
	}

	if ( $params->{from} ) {
		$sql .= qq/ datestamp > '$params->{from}' AND /;
	}

	if ( $params->{'until'} ) {
		$sql .= qq/ datestamp < '$params->{'until'}' AND /;
	}

	if ( $params->{set} ) {
		$sql .= qq/setSpec = '$params->{set}' AND /;
	}

	$sql .= q/1=1/;
	return $sql;
}

sub _updateRecord {
	my $self   = shift or die "Need myself!";
	my $record = shift or return;

	my $up =
	  q/UPDATE records SET datestamp=?, native_md =? / . q/WHERE identifier=?/;

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
	croak "No database handle!" if ( !$dbh );

	#Debug "UPDATE:$up";
	my $sth = $dbh->prepare($up) or croak $dbh->errstr();
	$sth->execute( $record->datestamp, $record->metadata->toString,
		$record->identifier )
	  or croak $dbh->errstr();
	return 1;    #success
}

sub _insertRecord {
	my $self   = shift or die "Need myself!";
	my $record = shift or return;
	my $header = $record->header;
	my $in = q/INSERT INTO records(identifier, datestamp, native_md, status) /;
	$in .= q/VALUES (?,?,?,?)/;

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
	croak "No database handle!" if ( !$dbh );

	#Debug "INSERT:$in";
	my $sth = $dbh->prepare($in) or croak $dbh->errstr();
	my $status;
	$sth->execute(
		$header->identifier,         $header->datestamp,
		$record->metadata->toString, $header->status
	) or croak $dbh->errstr();
	return 1;
}

=method my $datestamp=$engine->_datestampDB($record); 
	Returns the datestamp saved in the db for the identifier in record. (It 
	does $record->header->identifier internally.)
	
	Returns empty/false on error.
	
	Gets called only in storeRecord at this time.
=cut

sub _datestampDB {
	my $self   = shift or die "Need myself!";
	my $record = shift or return;

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
	croak "No database handle!" if ( !$dbh );

	my $check = qq(SELECT datestamp FROM records WHERE identifier = ?);
	my $sth = $dbh->prepare($check) or croak $dbh->errstr();
	$sth->execute( $record->identifier ) or croak $dbh->errstr();
	return $sth->fetchrow_array;
}

sub _updateSets {
	my $self   = shift or croak "Need myself";
	my $record = shift or croak "Need record";

	#Debug "delete Sets for record $identifier";
	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
	croak "No database handle!" if ( !$dbh );

	my $sql = qq/DELETE FROM sets WHERE identifier=?/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute( $record->identifier ) or croak $dbh->errstr();

	if ( $record->header->setSpec ) {
		foreach my $set ( $record->header->setSpec ) {

			#Debug "write new set:" . $set;
			my $addSet =
			  q/INSERT INTO sets (setSpec, identifier) VALUES (?, ?)/;
			$sth = $dbh->prepare($addSet) or croak $dbh->errstr();
			$sth->execute( $set, $record->header->identifier )
			  or croak $dbh->errstr();
		}
	}
	return 1;    #success
}

1;