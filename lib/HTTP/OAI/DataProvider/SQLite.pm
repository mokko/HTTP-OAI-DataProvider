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
use Dancer::CommandLine qw/Debug Warning/;
use Carp qw/carp croak/;
use DBI;
our $dbh;
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
	my $self=shift;

	my $sql=qq/SELECT MIN (datestamp) FROM records/;
	my $sth = $dbh->prepare($sql) or croak $dbh->errstr();
	$sth->execute() or croak $dbh->errstr();

	my $aref = $sth->fetch;

	if (! $aref->[0]) {
		Warning "No date";
	}

	$aref->[0]=~/(^\d{4}-\d{2}-\d{2})/;

	if (!$1)  {
		Warning "No date pattern found!";
		return();
	}

	return $1;

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
	$dbh->do("PRAGMA cache_size = 8000"); #doesn't make a big difference
	#default is 2000

	#I could make identifier the primary key. What are advantages and
	#disadvantages? I guess primary key cannot be text

	my $sql = q /CREATE TABLE if not exists sets (
  		'setSpec' STRING NOT NULL,
  		'identifier' TEXT NOT NULL REFERENCES records(identifier))/;

	#Debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;

	$sql = q/CREATE TABLE if not exists records (
  		'identifier' TEXT PRIMARY KEY NOT NULL ,
  		'datestamp'  TEXT NOT NULL ,
  		'native_md' BLOB)/;

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

