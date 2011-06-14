package HTTP::OAI::DataProvider::SQLite;
# ABSTRACT: A sqlite engine for HTTP::OAI::DataProvider

use warnings;
use strict;
use YAML::Syck qw/Dump LoadFile/;

use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_date/;
use HTTP::OAI::DataProvider::Engine::Result;

use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::SAX::Writer;
use Dancer::CommandLine qw/Debug Warning/;
use Carp qw/carp croak/;
use DBI qw(:sql_types);    #new
use DBIx::Connector;
use parent qw(HTTP::OAI::DataProvider::Engine);


=head1 SYNOPSIS

1) Fill db
	use HTTP::OAI::DataProvider::SQLite;
	my $engine=new HTTP::OAI::DataProvider::SQLite (ns_prefix=>$prefix,
		ns_uri=$uri);
	my $err=$engine->digest_single (...);

2) Use engine
	use HTTP::OAI::DataProvider::SQLite;
	my $engine=new HTTP::OAI::DataProvider::SQLite(
		ns_prefix=>$prefix, ns_uri=$uri,
		transformer=>$transformer,
		);

	my $header=$engine->findByIdentifier($identifier);
	my $result=$engine->queryHeaders($params);
	my $result=$engine->queryRecords($params);

	TODO

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

TODO: See if I want to use base or parent?
only for debug during development

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
}

=head2 my $response=$engine->queryChunk($chunkDescription);

Takes a chunkDescription, queries the db with it, parses the answer in a result
object and transforms the result to a response and returns to dancer.

Expects a chunkDescription. (A chunkDesc is SQL statement and some other
contextual info). It returns that chunk as a HTTP::OAI::Response object
(either HTTP::OAI::ListIdentifiers or HTTP::OAI::ListRecords.)

The chunkDescription is a hashref which is structured like this, see
HTTP::OAI::DataProvider::ChunkCache:
	$chunkDescription={
			chunkNo=>$chunkNo,
			maxChunkNo=>$maxChunkNo,
			[ next=>$tokenN, ]
			sql=>$sql,
			targetPrefix=>$prefix,
			token=>$token,
			total=>$total
	};

The last chunk doesn't have a next key. (?)

Gets called in queryChunk and in (the badly named) data provider's chunkExist.

=cut

sub queryChunk {
	my $self      = shift;
	my $chunkDesc = shift;
	my $params    = shift;
	my $request   = shift;    #optional

	$self->argumentExists($chunkDesc);
	$self->argumentExists($params);

	#Debug "Enter queryChunk";

	my %opts = (
		requestURL  => $self->{requestURL},
		transformer => $self->{transformer},
		verb        => $params->{verb},
		params      => $params,

		#for resumptionToken
		chunkSize    => $self->{chunkSize},
		chunkNo      => $chunkDesc->{chunkNo},
		targetPrefix => $chunkDesc->{targetPrefix},
		token        => $chunkDesc->{token},
		total        => $chunkDesc->{total},
	);

	#next is optional because last chunk has no next
	if ( $chunkDesc->{'next'} ) {
		$opts{'next'} = $chunkDesc->{'next'},;
	} else {
		Debug "queryChunk: this is the last chunk!";
		$opts{'last'} = 1;
	}

	my $result = new HTTP::OAI::DataProvider::Engine::Result(%opts);

	if ($request) {
		$result->{requestURL} = $request;    #overwrites value from above!
		     #Debug ":requestURL:".$result->{requestURL};
	}

	#SQL
	my $dbh = $self->{connection}->dbh()         or die $DBI::errstr;
	my $sth = $dbh->prepare( $chunkDesc->{sql} ) or croak $dbh->errstr();
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
				$md = $aref->[4];
			} else {

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

	#save the last record
	#in case there is only one record we get here!
	$result->save(
		header => $header,
		md     => $md,
	);

	# Check result
	if ( $result->isError ) {
		return $self->err2XML( $result->isError );
	}

	#transform result to response
	my $response = $result->getResponse;
	return $response;
}

=head2 my $cache=HTTP::OAI::DataRepository::SQLite::new (@args);

Am currently not sure about the arguments. Currently i accept everything,
so invocation has to be selective.

=cut

sub new {
	my $class = shift;
	my %args  = @_;
	my $self  = \%args;
	bless $self, $class;

	$self->checkRequired( 'dbfile', 'chunkSize' );

	#Debug "Enter HTTP::OAI::DataProvider::Engine::_new";
	#i could check if directory in $dbfile exists; if not provide
	#intelligble warning that path is strange

	$self->_connect_db( $self->{dbfile} );
	$self->_init_db();

	#I cannot test earlierstDate since non existant in new db
	#$self->earliestDate();    #just to see if this creates an error;

	return $self;
}

=head2 my $date=$engine->earliestDate();

Maybe your Identify callback wants to call this to get the earliest date for
the Identify verb.

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

		#croak "No date";
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

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

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

=head2 $result=$provider->query ($params);

Gets called from GetRecord, ListRecords, ListIdentifiers. Possible parameters
are metadataPrefix, from, until and Set. (Queries including a resumptionToken
should not get here.)

Plans chunking, save request chunks in cache and returns the first chunk as
HTTP::OAI::DataProvider::Result object.

TODO: What to do on failure?
TODO: Deal with a GetRecord request. Should this take place in planChunking?

TODO: do i still need isError?
Test for failure:
if ($result->isError) {
	#do this
}

=cut

sub query {
	my $self    = shift;
	my $params  = shift;
	my $request = shift;    #optional?

	$self->argumentExists($params);

	#get here if called without resumptionToken
	my $first = $self->planChunking($params);

	#if there are no results there is no first chunk
	if ( !$first ) {
		return ();
	}

	my $response = $self->queryChunk( $first, $params, $request );

	#todo: we still have to test if result has any result at all

	return $response;
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

=head2 my $sql=$self->querySQL ($params,$limit, $offset);

Returns the sql for the query (includes metadata for GetRecord and
ListRecords).

=cut

sub querySQL {
	my $self = shift;
	my %args = @_;

	my $params = $args{params};
	my $limit  = $args{limit};
	my $offset = $args{offset};

	#Debug "OFFSET: $offset LIMIT: $limit";
	#md becomes modifier with values md and count?
	# SELECT COUNT records.identifier FROM records WHERE
	# records.identifier = ? AND
	# datestamp > ? AND
	# datestamp < ? AND
	# setSpec = ?

	#This version is SLOW, but does it really matter? It's just one query
	#for each request. Who cares?

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

	if ( $params->{from} ) {
		$sql .= qq/ datestamp > '$params->{from}' AND /;
	}

	if ( $params->{until} ) {
		$sql .= qq/ datestamp < '$params-> {until}' AND /;
	}

	if ( $params->{set} ) {
		$sql .= qq/setSpec = '$params->{set}' AND /;
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

#
#
#

=head1 Internal Methods - to be called from other inside this module

=head2 my $connection=_connect_db ($dbfile);

Now uses DBIx::Connector

my $dbh=$connection->dbh;

=cut

sub _connect_db {
	my $self   = shift;
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

	#do NOT test if provider was born with chunking ability on intention!
	#total: total # of responses
	my ( $total, $maxChunkNo ) = $self->_mk_numbers($params);

	Debug "planChunking: total records:$total, maxChunkNo:$maxChunkNo";

	#what about an empty database?
	if ( $total == 0 ) {
		return ();
	}

	my $first;
	my $chunkNo      = 1;
	my $currentToken = $self->mkToken();
	my $chunkSize    = $self->{chunkSize};
	my $chunkCache   = $self->{chunkCache};

	#create all chunkDescriptions in chunkCache
	while ( $chunkNo <= $maxChunkNo ) {
		my $offset = ( $chunkNo - 1 ) * $chunkSize;    #or with +1?
		     #Debug "OFFSET: $offset CHUNKSIZE: $chunkSize";
		my $sql = $self->querySQL(
			limit  => $chunkSize,
			offset => $offset,
			params => $params,
		);
		my $nextToken = $self->mkToken();

		my $chunk = {
			chunkNo      => $chunkNo,
			maxChunkNo   => $maxChunkNo,
			sql          => $sql,
			targetPrefix => $params->{metadataPrefix},
			token        => $currentToken,
			total        => $total
		};

		#the last chunk has no resumption token
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

	#TODO
	#only check for 2nd chunk if there is more than 1
	#i don't really need this sanity check
	if ( $maxChunkNo > 1 && $params->{verb} ne 'GetRecord' ) {

		#sanity check: can I find the 2nd chunk in chunkCache
		my $secondToken = $first->{next};

		#Debug "secondToken:".$secondToken;
		my $secondChunk = $chunkCache->get($secondToken);
		if ($secondChunk) {
			Debug "2nd CHUNK FOUND" . $secondChunk->{token};
		} else {

			#die "2nd chunk not found in cache";
		}
	}

	#Debug "planChunking RESULT".$self->{chunkCache}->count;
	return $first;
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

sub _init_db {

	#Debug "Enter _init_db";
	my $self = shift;
	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

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

#hide that ugly code
sub _mk_numbers {
	my $self   = shift;
	my $params = shift;
	my $total  = $self->_countTotals($params);

	#e.g. 2222 total with 500 chunk size: 1, 501, 1001, 1501, 2001
	my $max = ( $total / $self->chunkSize ) + 1;    #max no of chunks
	return $total, sprintf( "%d", $max );           #rounded up to int
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
		$sql .= qq/ datestamp < '$params-> {until}' AND /;
	}

	if ( $params->{set} ) {
		$sql .= qq/setSpec = '$params->{set}' AND /;
	}

	$sql .= q/1=1/;
	return $sql;
}

sub _registerNS {
	my $self = shift;
	my $doc  = shift;

	#Debug 'Enter _registerNS';

	if ( $self->{nativePrefix} ) {
		if ( !$self->{nativeURI} ) {
			croak "ns_prefix specified, but ns_uri missing";
		}

		#Debug 'ns: ' . $self->{nativePrefix} . ':' . $self->{nativeURI};

		$doc = XML::LibXML::XPathContext->new($doc);
		$doc->registerNs( $self->{nativePrefix}, $self->{nativeURI} );
	}
	return $doc;
}

#store record in db
sub _storeRecord {
	my $self   = shift;
	my $record = shift;

	my $header     = $record->header;
	my $md         = $record->metadata;
	my $identifier = $header->identifier;
	my $datestamp  = $header->datestamp;

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

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
			my $up = q/UPDATE records SET datestamp=?, native_md =? /
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

=method $self->checkRequired ('a','b');

	Carps if 'a' or 'b' are not exist (as $self->{a} and $self->{b}).

=cut

sub checkRequired {
	my $self = shift;
	foreach (@_) {
		if ( !$self->{$_} ) {
			carp "Error: need $_";
		}
	}
}

1;

