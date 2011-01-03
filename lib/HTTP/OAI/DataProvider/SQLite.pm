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

HTTP::OAI::DataProvider::SQLite - Create/query OAI header information and store
it in sqlite.

=head1 SYNOPSIS

	#PHASE 1: Creating new cache
	use HTTP::OAI::DataProvider::SQLite qw/import_single import_dir/;
	my $cache=new HTTP::OAI::DataProvider::SQLite (ns_prefix=>$prefix,
		ns_uri=$uri);


	my $err=$cache->digest_single (source=>$xml_fn, mapping=>&mapping);
	#my $err=$cache->digest_dir (source=>$xml_fn, mapping=>&mapping);

	#PHASE2: Using the cache
	use HTTP::OAI::DataProvider::SQLite::HeaderCache
	my $cache=new HTTP::OAI::DataProvider::SQLite::HeaderCache(
		ns_prefix=>$prefix, ns_uri=$uri);

	$result=$cache->query(from=>$from, until=>$until, set=>$set);

=head1 DESCRIPTION

Provide a db for HTTP::OAI::DataProvider and abstract all the database action.

=cut

=head2 debug "blabla bla";
=cut

sub debug {
	my $msg = shift;

	if ( $msg && $debug gt 0 ) {
		print $msg. "\n";
	}
}

=head2 	my $err=$cache->digest_single (source=>$xml_fn, mapping=>&mapping);
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
		croak "No document for whatever reason";
	}

	if ( !$args{mapping} ) {
		croak "No mapping callback specified";
	}

	#debug "test: " . $args{mapping};

	no strict "refs";

	#I don't know how to do this with arrow notation
	my @records = &{ $args{mapping} }( $self, $doc );
	use strict "refs";

	foreach my $record (@records) {

		#$self->_practice_select($header);

		$self->_storeRecord($record);
		#debug 'record:' . $record->metadata->toString;

		#$self->_showRecord($record);

		#insert into sqlite ONLY if not already there

	}
}

=head2 $self->showRecord($record);
=cut

sub _showRecord {
	my $self=shift;
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
	my $sql = q /CREATE TABLE if not exists sets (
  		'setSpec' string not null,
  		'recordID' integer not null)/;

	#debug $sql. "\n";
	$dbh->do($sql) or die $dbh->errstr;

	$sql = q/CREATE TABLE if not exists records (
  		'id' integer primary key autoincrement,
  		'identifier' text not null,
  		'datestamp'  text not null,
  		'native_md' blob)/;

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

	my $header= $record->header;
	my $md=$record->metadata;
	my $identifier = $header->identifier;
	my $datestamp  = $header->datestamp;

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


	my $up = qq(UPDATE records SET datestamp=?, native_md=? WHERE
		identifier=?);
	my $in = qq/INSERT INTO records(identifier, datestamp, native_md) VALUES
		(?,?,?)/;

	my $id = qq/SELECT id FROM records WHERE identifier=?/;

	#attempt update
	my $sth = $dbh->prepare($up) or croak $dbh->errstr();
	$sth->execute( $datestamp, $md->toString, $identifier ) or croak $dbh->errstr();

	#attempt insert
	if ( $sth->rows == 0 ) {
		my $sth = $dbh->prepare($in) or croak $dbh->errstr();
		$sth->execute( $identifier, $datestamp,$md->toString ) or croak $dbh->errstr();
		$id = $dbh->last_insert_id( undef, undef, 'records', undef );
		debug "  insert-id: $id";
	} else {

		#all this trouble for last_update_id?
		my $sth = $dbh->prepare($id) or croak $dbh->errstr();
		$sth->execute($identifier) or croak $dbh->errstr();
		$id = $sth->fetch->[0];
		debug "  update-id: $id";
	}

	debug "rows affected:";

	#delete all sets with that recordID
	#debug "delete Sets for record $id";
	my $deleteSets = qq/DELETE FROM sets WHERE recordID=?/;
	$sth = $dbh->prepare($deleteSets) or croak $dbh->errstr();
	$sth->execute($id) or croak $dbh->errstr();

	if ( $header->setSpec ) {
		foreach my $set ( $header->setSpec ) {

			#debug "write new set:" . $set;
			my $addSet = qq/INSERT INTO sets (setSpec, recordID) VALUES
				(?, ?)/;
			$sth = $dbh->prepare($addSet) or croak $dbh->errstr();
			$sth->execute( $set, $id ) or croak $dbh->errstr();

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

