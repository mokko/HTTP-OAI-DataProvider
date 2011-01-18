package HTTP::OAI::DataProvider::SQLite;

use warnings;
use strict;
use YAML::Syck qw/Dump LoadFile/;

#use XML::LibXML;
use HTTP::OAI;
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::SAX::Writer;
use Dancer::CommandLine qw/Debug Warning/;
use Carp qw/carp croak/;
use DBI;
our $dbh;

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
		ns_prefix=>$prefix, ns_uri=$uri

		);

	$result=$engine->query(from=>$from, until=>$until, set=>$set);
	TODO

=head1 DESCRIPTION

Provide a sqlite for HTTP::OAI::DataProvider and abstract all the database
action to store, modify and access header and metadata information.

=head2 	my $err=$engine->digest_single (source=>$xml_fn, mapping=>&mapping);
=cut

sub digest_single {
	my $self = shift;
	my %args = @_;

	Debug "Enter digest_single";

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

=head2 $self->showRecord($record);
=cut

sub showRecord {
	my $self   = shift;
	my $record = shift;
	Debug "Enter showRecord";

	if ( $record->header ) {
		Debug "--HEADER--";
		Debug $record->header->dom->toString;

	}
	if ( $record->metadata ) {
		Debug "--METADATA--";
		Debug $record->metadata->toString;
	}
	if ( $record->about ) {
		Debug "--ABOUT--";
		Debug $record->metadata->toString;
	}

	#	my $list= new HTTP::OAI::ListRecord;
	#	$list->record($record);
	#	Debug $list->toDOM->toString;
	#my $gr = new HTTP::OAI::GetRecord();
	#$gr->record($record);

	#Debug $gr->toDOM;

	#Debug 'writer:'. $gr->toDOM()->toString;
	#my $writer = XML::SAX::Writer->new();
	#$record->set_handler($writer);
	#$record->generate;
	#Debug "wewe" . $writer;
}

=head2 my $cache=new HTTP::OAI::DataRepository::SQLite (
	mapping=>'main::mapping',
	ns_prefix=>'mpx',
	ns_uri=>''
);
=cut

sub new {
	my $self  = {};
	my $class = shift;

	my %args = @_;

	Debug "Enter HTTP::OAI::DataProvider::SQLite::new";

	if ( !$args{dbfile} ) {
		carp "Error: need dbfile";
	}

	if ( $args{ns_uri} ) {
		$self->{ns_uri} = $args{ns_uri};
	}

	if ( $args{ns_prefix} ) {
		$self->{ns_prefix} = $args{ns_prefix};
	}

	#i could check if directory in $dbfile exists; if not provide
	#intelligble warning that path is strange

	bless( $self, $class );

	_connect_db( $args{dbfile} );
	_init_db();

	return $self;
}

=head1 my $date=$engine->earliestDate();

Maybe your Identify callback wants to call this to get the earliest date for
the Identify verb.

=cut

sub earliestDate {
	my $self = shift;

	my $sql = qq/SELECT MIN (datestamp) FROM records/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $aref = $sth->fetch;

	if ( !$aref->[0] ) {
		Warning "No date";
	}

	$aref->[0] =~ /(^\d{4}-\d{2}-\d{2})/;

	if ( !$1 ) {
		Warning "No date pattern found!";
		return ();
	}

	return $1;

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

	my $long    = 'YYYY-MM-DDThh:mm:ssZ';
	my $short   = 'YYYY-MM-DD';
	my $default = $long;

	my $sql = q/SELECT datestamp FROM records/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	# alternative is to test each and every record
	# not such a bad idea to do this during Identify
	#	while (my $aref=$sth->fetch) {
	#	}

	my $aref = $sth->fetch;

	if ( !$aref->[0] ) {
		Debug "granuarity cannot find a datestamp and hence assumes $default";
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

		my $h = new HTTP::OAI::Header;
		$h->identifier = $identifier;
		$h->datestamp  = $aref->[0];

		#TODO $h->status=$aref->[1];

		while ( $aref = $sth->fetch ) {
			if ( $aref->[1] ) {
				$h->setSpec( $aref->[1] );
			}
		}
		return $h;
	}
}

=head2 listSets TODO

Return those setSpecs which are actually used in the store. Expects nothing,
returns an array of setSpecs as string. Called from DataProvider::ListSets.

=cut

sub listSets {
	my $self = shift;

	Debug "Enter ListSets";

	my $sql = q/SELECT DISTINCT setSpec FROM sets ORDER BY setSpec ASC/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	#can this be done easier without another setSpec?
	my @setSpecs;
	while ( my $aref = $sth->fetch ) {
		Debug "listSets:setSpec='$aref->[0]'";
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
	my $result = {};
	bless $result, 'HTTP::OAI::DataProvider::SQLite';
	my @errors;

	#should already be tested, so only croak
	if ( !$params->{metadataPrefix} ) {
		Debug Dumper $params;
		croak "metadataPrefix missing!";
	}

	#NOT sure if this has been tested already
	#It's a bit unexpected that if validation succeeds when it fails, but who
	#cares really?
	foreach (qw/until from/) {
		if ( $params->{$_} ) {
			if ( validate_date $params->{$_} ) {
				push(
					@errors,
					new HTTP::OAI::Error(
						code    => 'badArgument',
						message => "Argument $_ is not a valid date"
					)
				);
			}
		}
	}

	if (@errors) {
		$result->{errors} = @errors;
		return $result;
	}

	my $sql = q/SELECT records.identifier, datestamp, status, setSpec
	FROM records JOIN sets ON records.identifier = sets.identifier/;

	#About order: I could add "ORDER BY records.identifier ASC" which gives us
	#strict alphabetical order. Not want is expected. That wdn't really be a
	#problem, but not nice. Now we have the order we put'em in. Less reliable,
	#but more intuitive. Until it goes wrong.
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $header;
	my $i       = 0;     #count the results so you can test if none
	my $last_id = '';    #needs to be an empty string
	my $LI = new HTTP::OAI::ListIdentifiers;
	while ( my $aref = $sth->fetch ) {
		$i++;

		#Debug Dumper $aref;

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

	if ( $i == 0 ) {
		push( @errors, new HTTP::OAI::Error( code => 'noRecordsMatch', ) );
	}

	if (@errors) {
		$result->{errors} = @errors;
		return $result;
	}
	$result->{ListIdentifiers} = $LI;
	return $result;
}

=head2 isError
	if ($cache->isError){
		#do in case of error
	}
	#return usually contains HTTP::OAI::Error, but not always
	my @return=$cache->isError

=cut

sub isError {
	my $self = shift;
	if ( exists $self->{errors} ) {
		return @{ $self->{errors} };
	}
	return ();
}

#
#
#

=head1 Internal Methods - to be called from other inside this module

=cut

sub _connect_db {
	my $dbfile = shift;
	Debug "Connecting to $dbfile...";

	$dbh = DBI->connect(
		"dbi:SQLite:dbname=$dbfile",
		'', '',
		{
			sqlite_unicode => 1,
			RaiseError     => 1
		}
	  )
	  or die $DBI::errstr;
}

sub _init_db {
	Debug "Enter _init_db";

	if ( !$dbh ) {
		carp "Error: database handle missing";
	}

	$dbh->do("PRAGMA foreign_keys");
	$dbh->do("PRAGMA cache_size = 8000");    #doesn't make a big difference
	                                         #default is 2000

	#I could make identifier the primary key. What are advantages and
	#disadvantages? I guess primary key cannot be text

	my $sql = q / CREATE TABLE IF NOT EXISTS sets(
		'setSpec' STRING NOT NULL,
		'identifier' TEXT NOT NULL REFERENCES records(identifier)
	)/;

	#Debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;

	#TODO: Status not yet implemented
	$sql = q/CREATE TABLE IF NOT EXISTS records (
  		'identifier' TEXT PRIMARY KEY NOT NULL ,
  		'datestamp'  TEXT NOT NULL ,
  		'status'     INTEGER -- null or 1,
  		'native_md'  BLOB)/;

	#Debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;
}

#my $doc=$cache->_loadXML ($file);
sub _loadXML {
	my $self     = shift;
	my $location = shift;

	Debug "Enter _loadXML ($location)";

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

sub _registerNS {
	my $self = shift;
	my $doc  = shift;

	Debug 'Enter _registerNS';

	if ( $self->{ns_prefix} ) {
		if ( !$self->{ns_uri} ) {
			croak "ns_prefix specified, but ns_uri missing";
		}
		Debug 'ns: ' . $self->{ns_prefix} . ':' . $self->{ns_uri};

		$doc = XML::LibXML::XPathContext->new($doc);
		$doc->registerNs( $self->{ns_prefix}, $self->{ns_uri} );
	}
	return $doc;
}

sub _storeRecord {
	my $self   = shift;
	my $record = shift;

	my $header     = $record->header;
	my $md         = $record->metadata;
	my $identifier = $header->identifier;
	my $datestamp  = $header->datestamp;

	#todo: overwrite only those items where datestamp is equal or newer

	Debug "Enter _storeRecord";

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
			Debug "$identifier exists and date equal or newer -> update";
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
		Debug "$identifier new -> insert";

		#if no datestamp, then no record -> insert one
		#this implies every record MUST have a datestamp!
		my $in =
		    q/INSERT INTO records(identifier, datestamp, native_md)/
		  . q/VALUES (?,?,?)/;

		#Debug "INSERT:$in";
		my $sth = $dbh->prepare($in) or croak $dbh->errstr();
		$sth->execute( $identifier, $datestamp, $md->toString )
		  or croak $dbh->errstr();
	}

	Debug "delete Sets for record $identifier";
	my $deleteSets = qq/DELETE FROM sets WHERE identifier=?/;
	$sth = $dbh->prepare($deleteSets) or croak $dbh->errstr();
	$sth->execute($identifier) or croak $dbh->errstr();

	if ( $header->setSpec ) {
		foreach my $set ( $header->setSpec ) {
			Debug "write new set:" . $set;
			my $addSet =
			  q/INSERT INTO sets (setSpec, identifier) VALUES (?, ?)/;
			$sth = $dbh->prepare($addSet) or croak $dbh->errstr();
			$sth->execute( $set, $identifier ) or croak $dbh->errstr();
		}
	}
}

1;

