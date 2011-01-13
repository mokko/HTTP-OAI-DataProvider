package HTTP::OAI::DataProvider::SQLite;

use warnings;
use strict;
use YAML::Syck qw/Dump LoadFile/;

#use XML::LibXML;
use HTTP::OAI;
use HTTP::OAI::Repository qw/:validate/;
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::SAX::Writer;
use Carp qw/carp croak/;
use DBI;
our $debug = 1;
our $dbh;
sub debug;
use Data::Dumper;

=head1 NAME

HTTP::OAI::DataProvider::SQLite - A sqlite engine for HTTP::OAI::DataProvider

=head1 SYNOPSIS

1) Creat a new cache
	use HTTP::OAI::DataProvider::SQLite;
	my $engine=new HTTP::OAI::DataProvider::SQLite (ns_prefix=>$prefix,
		ns_uri=$uri);

	my $err=$engine->digest_single (source=>$xml_fn, mapping=>&mapping);

2) Use the cache
	use HTTP::OAI::DataProvider::SQLite::HeaderCache;
	my $engine=new HTTP::OAI::DataProvider::SQLite(
		ns_prefix=>$prefix, ns_uri=$uri);

	$result=$engine->query(from=>$from, until=>$until, set=>$set);
	TODO


=head1 DESCRIPTION

Provide a sqlite for HTTP::OAI::DataProvider and abstract all the database
action to store, modify and access header and metadata information.

=cut

=head2 debug "blabla bla";

TODO: Should go to HTTP::OAI::DataProvider or similar.

=cut

sub debug {
	my $msg = shift;

	if ( $msg && $debug gt 0 ) {
		print $msg. "\n";
	}
}

=head2 	my $err=$engine->digest_single (source=>$xml_fn, mapping=>&mapping);
=cut

sub digest_single {
	my $self = shift;
	my %args = @_;

	debug "Enter digest_single";

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

	#debug "test: " . $args{mapping};

	my $mapping = $args{mapping};
	no strict "refs";
	while ( my $record = $self->$mapping($doc) ) {
		$self->_storeRecord($record);
	}
	use strict "refs";

}

=head2 $self->showRecord($record);
=cut

sub _showRecord {
	my $self   = shift;
	my $record = shift;
	debug "Enter showRecord";

	if ( $record->header ) {
		debug "--HEADER--";
		debug $record->header->dom->toString;

	}
	if ( $record->metadata ) {
		debug "--METADATA--";
		debug $record->metadata->toString;
	}
	if ( $record->about ) {
		debug "--ABOUT--";
		debug $record->metadata->toString;
	}

	#	my $list= new HTTP::OAI::ListRecord;
	#	$list->record($record);
	#	debug $list->toDOM->toString;
	#my $gr = new HTTP::OAI::GetRecord();
	#$gr->record($record);

	#debug $gr->toDOM;

	#debug 'writer:'. $gr->toDOM()->toString;
	#my $writer = XML::SAX::Writer->new();
	#$record->set_handler($writer);
	#$record->generate;
	#debug "wewe" . $writer;
}

#outdated db scheme
sub _practice_select {
	my $header = shift;
	my ( $records_id, $identifier, $datestamp, $setSpec );
	my $sth = $dbh->prepare(
		qq/SELECT records.id, identifier, datestamp, sets.setSpec FROM
		records JOIN sets ON records.id = sets.recordID/
	)               or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();
	$sth->bind_columns( \( $records_id, $identifier, $datestamp, $setSpec ) );

	# Column binding is the most efficient way to fetch data
	while ( $sth->fetch ) {
		print "$records_id: $identifier $datestamp, $setSpec\n";
	}
	exit;
}

=head2 my $cache=new HTTP::OAI::DataRepository::SQLite (
	debug=>1,
	mapping=>'main::mapping',
	ns_prefix=>'mpx',
	ns_uri=>''
);
=cut

sub new {
	my $self  = {};
	my $class = shift;

	my %args = @_;

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

	if ( $args{debug} ) {
		$debug = $args{debug};
	}

	bless( $self, $class );

	_connect_db( $args{dbfile} );
	_init_db();

	return $self;
}

#
#
#

=head1 Internal Methods - to be called from other inside this module

=cut

sub _connect_db {
	my $dbfile = shift;
	debug "Connecting to $dbfile...";

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
	debug "Enter _init_db";

	if ( !$dbh ) {
		carp "Error: database handle missing";
	}

	$dbh->do("PRAGMA foreign_keys");
	$dbh->do("PRAGMA cache_size = 8000"); #doesn't make a big difference
	#default is 2000

	#I could make identifier the primary key. What are advantages and
	#disadvantages? I guess primary key cannot be text

	my $sql = q /CREATE TABLE if not exists sets (
  		'setSpec' STRING NOT NULL,
  		'identifier' TEXT NOT NULL REFERENCES records(identifier))/;

	#debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;

	$sql = q/CREATE TABLE if not exists records (
  		'identifier' TEXT PRIMARY KEY NOT NULL ,
  		'datestamp'  TEXT NOT NULL ,
  		'native_md' BLOB)/;

	#debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;
}

#my $doc=$cache->_loadXML ($file);
sub _loadXML {
	my $self     = shift;
	my $location = shift;

	debug "Enter _loadXML ($location)";

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

	debug 'Enter _registerNS';

	if ( $self->{ns_prefix} ) {
		if ( !$self->{ns_uri} ) {
			croak "ns_prefix specified, but ns_uri missing";
		}
		debug 'ns: ' . $self->{ns_prefix} . ':' . $self->{ns_uri};

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

	debug "Enter _storeRecord";

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

	#currently:
	#try to update and if update fails insert

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
		#debug "datestamp source: $datestamp // datestamp $datestamp_db";
		if ( $datestamp_db le $datestamp ) {
			debug "$identifier exists and date equal or newer -> update";
			my $up =
			    q/UPDATE records SET datestamp=?, native_md =? /
			  . q/WHERE identifier=?/;

			#debug "UPDATE:$up";
			my $sth = $dbh->prepare($up) or croak $dbh->errstr();
			$sth->execute( $datestamp, $md->toString, $identifier )
			  or croak $dbh->errstr();
		}

		#else: db date is older than current one -> NO update
	} else {
		debug "$identifier new -> insert";

		#if no datestamp, then no record -> insert one
		#this implies every record MUST have a datestamp!
		my $in =
		    q/INSERT INTO records(identifier, datestamp, native_md)/
		  . q/VALUES (?,?,?)/;
		#debug "INSERT:$in";
		my $sth = $dbh->prepare($in) or croak $dbh->errstr();
		$sth->execute( $identifier, $datestamp, $md->toString )
		  or croak $dbh->errstr();
	}

	debug "delete Sets for record $identifier";
	my $deleteSets = qq/DELETE FROM sets WHERE identifier=?/;
	$sth = $dbh->prepare($deleteSets) or croak $dbh->errstr();
	$sth->execute($identifier) or croak $dbh->errstr();

	if ( $header->setSpec ) {
		foreach my $set ( $header->setSpec ) {
			debug "write new set:" . $set;
			my $addSet =
			  q/INSERT INTO sets (setSpec, identifier) VALUES (?, ?)/;
			$sth = $dbh->prepare($addSet) or croak $dbh->errstr();
			$sth->execute( $set, $identifier ) or croak $dbh->errstr();
		}
	}
}

#outdated. Looking for better way to outsource something
sub _updateOrInsert {
	my $update = shift;
	my $insert = shift;
	my $id     = shift;
	debug "Enter _updateOrInsert";    # ($update,$insert)";

	#attempt update
	my $sth = $dbh->prepare($update) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	#attempt insert
	if ( $sth->rows == 0 ) {
		my $sth = $dbh->prepare($insert) or croak $dbh->errstr();
		$sth->execute() or croak $dbh->errstr();
		$id = $dbh->last_insert_id( undef, undef, 'records', undef );
	} else {

		#all this trouble for last_update_id
		my $sth = $dbh->prepare($id) or croak $dbh->errstr();
		$sth->execute() or croak $dbh->errstr();
		$id = $sth->fetch->[0];
	}

	debug "affected:" . $sth->rows . '(' . $id . ')';
	return $id;
}

1;

