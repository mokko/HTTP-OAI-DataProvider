package HTTP::OAI::DataProvider::SQLite;

use warnings;
use strict;
use YAML::Syck qw/Dump LoadFile/;

#use XML::LibXML;
use HTTP::OAI;
use HTTP::OAI::Repository qw/validate_date/;
use HTTP::OAI::DataProvider::Result;
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
		transformer=>$transformer,
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
}

=head2 my $cache=new HTTP::OAI::DataRepository::SQLite (
	mapping=>'main::mapping',
	ns_prefix=>'mpx',
	ns_uri=>''
);
=cut

sub new {
	my $class = shift;
	my $args  = @_;
	my $self  = {};
	bless $self, $class;

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
	my $dbh  = $self->{connection}->dbh() or die $DBI::errstr;
	my $sql  = qq/SELECT MIN (datestamp) FROM records/;
	my $sth  = $dbh->prepare($sql) or croak $dbh->errstr();
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
	my $dbh  = $self->{connection}->dbh() or die $DBI::errstr;

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
	my $self    = shift;
	my $params  = shift;
	my $request = shift;

	$self->_countTotals($params)
	  ;    #save total in $engine->{requestChunk}->{total}
	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

	#Debug "Enter queryHeaders ($params)";
	#transformer is obligatory
	my $result = new HTTP::OAI::DataProvider::Result($self);

	#request and resumption are optional
	if ($request) {
		$result->{requestURL} = $request;
	}

	# metadata munging
	my $sql = _querySQL($params);

	#Debug $sql;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $i = $self->parseHeaders( $result, $sth );

	#Debug "queryHeaders found $i headers";
	# Check result
	if ( $i == 0 ) {
		$result->addError('noRecordsMatch');
	}

	return $result;
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

sub parseHeaders {
	my $self   = shift;    #$engine
	my $result = shift;
	my $sth    = shift;

	if ( !$sth ) {
		Warning "Something's wrong with \$sth!";
	}
	if ( !$result ) {
		Warning "Something's wrong with \$result!";
	}

	if ( ref $result ne 'HTTP::OAI::DataProvider::Result' ) {
		Warning "Something's wrong!";
	}

	#Debug "Parsing headers";

	my $header;
	my $i       = 0;     #count the results to test if none
	my $last_id = '';    #needs to be an empty string
	while ( my $aref = $sth->fetch ) {

		#Debug "Inside while";

		#$i++;            #counts lines not records
		if ( $last_id ne $aref->[0] ) {
			$i++;        #counts records

			#a new item with new identifier
			$header = new HTTP::OAI::Header;
			$header->identifier( $aref->[0] );
			$header->datestamp( $aref->[1] );
			if ( $aref->[2] ) {
				$header->status('deleted');
			}
		}
		if ( $aref->[3] ) {
			my $set = new HTTP::OAI::Set;
			$set->setSpec( $aref->[3] );
			$header->setSpec($set);
		}

		#save current identifier to weed out duplicates
		$last_id = $aref->[0];
		$result->addHeader($header);

		#addHeader calls $result->chunk and that should set EOFChunk
		#when chunk is full; NOT {EOFChunk}!
		#save state
		if ( $result->EOFChunk ) {
			$result->chunkRequest( sth => $sth, type => 'header' );
			return $result;    #break loop
		}
	}

	#don't we have to add the laster Header? Todo:untested!
	if ($header) {
		$result->addHeader($header);
	}

	#loop is finished! No records in sth
	#if while loop is over-> raise CurChunkNo
	my $chunkRequest = $result->chunkRequest;
	$chunkRequest->{curChunkNo}++;
	return $i;
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
	my $self    = shift;    #is initialized only once, cannot carry requestURL
	my $params  = shift;
	my $request = shift;

	#save total in $engine->{requestChunk}->{total}
	$self->_countTotals($params);

	#transformer is obligatory
	my $result = new HTTP::OAI::DataProvider::Result($self);

	#request and resumption are optional
	if ($request) {
		$result->{requestURL} = $request;
	}

	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;

	#Debug "Enter queryRecords ($params)";
	# metadata munging
	my $sql = _querySQL( $params, 'md' );

	#Debug $sql;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $i = $self->parseRecords( $result, $sth, $params );

	#Debug "queryRecords found matching $i headers";
	#does not make much of a difference
	#$stylesheet_cache{ $params->{metadataPrefix} } = undef;

	# Check result
	if ( $i == 0 ) {
		$result->addError('noRecordsMatch');
	}

	return $result;
}

sub parseRecords {
	my $self   = shift;
	my $result = shift;
	my $sth    = shift;
	my $params = shift;

	if ( !$sth or !$result or !$params ) {
		Warning "Something's wrong!";
	}

	if ( ref $result ne 'HTTP::OAI::DataProvider::Result' ) {
		Warning "Something's wrong!";
	}

	my $header;
	my $md;
	my $i       = 0;     #count the results to test if none
	my $last_id = '';    #needs to be an empty string

	#loop over db rows which contain redundant info (cartesian product)
	#I keep track of identifiers: if known it is a repetitive row
	#if header is already defined, have action before starting next header
	while ( my $aref = $sth->fetch ) {
		if ( $last_id ne $aref->[0] ) {
			$i++;        #count distinct identifiers
			if ($header) {

				#a new distinct id where header has already been defined
				#first time on the row which has the 2nd distinct id
				#i.e. previous header should be ready for storing it away

				$result->saveRecord(
					params => $params,
					header => $header,
					md     => $md,
				);

				#check here if first chunk is ready
				#Debug "break the loop, but save loop state";
				if ( $result->EOFChunk ) {

					#Debug "curPos" . $result->{posInChunk};
					#Debug "rt" . ref $result->EOFChunk;
					$result->chunkRequest(
						params => $params,
						sth    => $sth,
						type   => 'records',
					);
					return $i;    #break loop
				}

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
			}
		}

		#every row
		if ( $aref->[3] ) {
			$header->setSpec( $aref->[3] );
		}

		$last_id = $aref->[0];
	}

	#save the last record
	#for every last distinct identifier, so call it here since no iteration
	$result->saveRecord(
		params => $params,
		header => $header,
		md     => $md,
	);
	my $chunkRequest = $result->chunkRequest;
	$chunkRequest->{curChunkNo}++;

	#TODO: Decide i we need to save state here?
	return $i;
}

=head2 $engine->completeChunks;

WHAT IT SHOULD DO

1. test signal
completeChunks is called in Salsa_OAI after the first dance. It checks whether
there is a queryResult to be finished. It does so by checking
chunkRequest->{EOFChunk}. If that is set, it continues; otherwise it returns
without doing anything else.

2. Re-enter parseResult/parseHeader loop
If that signal is encountered, the loop should save its state and this method
should re-enter the loop in parseRecords / parseHeaders where it left off
(using the saved sate). Re-Entering the loop ONCE should be enough. Via the
loop $result->chunk the loop should be able to figure out what to do on its
own.

3. write remaining chunks to disk

Saving loop state

When: It should be necessary to save the loop state information only ONCE
when moving from normal route to after.

What: I need
-the statement handle
-the first token (for writing down the 2nd chunk under the name of the first
 token)

=cut

sub completeChunks {
	my $engine   = shift;
	my $provider = shift;

	#We do not have a result obj at this time, so we cannot call:
	#my $chunkRequest = $result->chunkRequest;

	my $chunkRequest = $engine->{chunkRequest};

	#Debug "Enter completeChunks";
	if ( $chunkRequest->{EOFChunk} ) {

		Debug "WORKING ON REMAINING CHUNKS!";

		#EOFChunk exists,i.e. chunking is on and we have come here to work on
		#remaining chunks

		#Debug "first token:" . $token;
		my $sth = $chunkRequest->{sth};

		if ($sth) {

			#Debug "statement handle:" . $sth;
		} else {
			Warning "No sth!" . $chunkRequest->{type};
		}

		Debug "requestURL" . $chunkRequest->{request};
		Debug "total items in request:" . $chunkRequest->{total};
		Debug "curChunkNo/maxChunkNo:"
		  . $chunkRequest->{curChunkNo} . '/'
		  . $chunkRequest->{maxChunkNo};

		#now we need that loop to break after each chunk
		while ( $chunkRequest->{curChunkNo} < $chunkRequest->{maxChunkNo} ) {
			my $rt        = $chunkRequest->{EOFChunk};
			my $old_token =
			  $rt->resumptionToken;    #rt was made when chunk was ready

			#rm EOFChunk so loop doesn't break there anymore until set again
			#gets set by $result->chunk if a chunk is full
			delete $chunkRequest->{EOFChunk};

			#I am still officially in chunk 1. I need to re-enter the loop to
			#raise the chunkNo
			#Debug "ENTER CHUNK NO" . $chunkRequest->{curChunkNo};

			#should we make a new result object for every chunk
			#that takes care of resetting record/header info in result
			#the QUESTION is if that messes with our chunkRequest info!?
			my $result = new HTTP::OAI::DataProvider::Result($engine);

			#HERE

			if ( $chunkRequest->{type} eq 'records' ) {
				my $params = $chunkRequest->{params};

				if ( !$params ) {
					Warning "Something's wrong";
				}

				#Debug "About to re-enter at parseRecords";
				$engine->parseRecords( $result, $sth, $params );
			} else {

				#Debug "About to re-enter at parseHeaders";
				$engine->parseHeaders( $result, $sth );
			}

			#new token!
			$rt = $chunkRequest->{EOFChunk};

			my $response = $result->getResponse;
			Debug "Chunk "
			  . $chunkRequest->{curChunkNo} . ' of '
			  . $chunkRequest->{maxChunkNo}
			  . ' parsed';
			$response->resumptionToken($rt);
			$response->request($chunkRequest->{request});
			Debug "response request".$response->request;
			#$result->responseCount();

			#_output applies xslt and replaces requestURL if necessary
			#chunkStr returns wrong output
			my $chunkStr = $provider->_output($response);

			#Debug "CHUNKSTR $chunkStr";
			$result->writeChunk( $chunkStr, $old_token );

			#Debug "Why does the loop end here?";
			#Debug "curChunkNo".$chunkRequest->{curChunkNo};
			#Debug "maxChunkNo".$chunkRequest->{maxChunkNo};
		}
	}
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
	  )
	  or die "Problems with DBIx::connector";
}

=head2 my $count=$self->_countTotals ($params);
Apparently, for resumptionToken I need to know the total number of results
(headers or records) before I start chunking. So this metho performs a query
and returns that number.

=cut

sub _countTotals {
	my $self   = shift;    #an engine, SQLite object
	my $params = shift;

	my $sql = $self->_queryCount($params);
	my $dbh = $self->{connection}->dbh() or die $DBI::errstr;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $aref = $sth->fetch;

	if ( !$aref->[0] ) {
		croak "No count";
	}

	#Debug "Sql: $sql";
	#Debug "COUNT: " . $aref->[0];
	$self->{chunkRequest}->{total} = $aref->[0];
}

sub _init_db {

	#Debug "Enter _init_db";
	my $self = shift;
	my $dbh  = $self->{connection}->dbh() or die $DBI::errstr;

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

sub _queryCount {
	my $self   = shift;
	my $params = shift;
	my $sql    = q/SELECT COUNT (DISTINCT records.identifier) FROM /;
	$sql .= q/records JOIN sets ON records.identifier = sets.identifier WHERE
	/;

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
	return $sql;
}

sub _querySQL {
	my $params = shift;
	my $md     = shift;

	#md becomes modifier with values md and count?
	# SELECT COUNT records.identifier FROM records WHERE
	# records.identifier = ? AND
	# datestamp > ? AND
	# datestamp < ? AND
	# setSpec = ?

	#This version is SLOW, but does it really matter? It's just one query
	#for each request. Who cares?

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

