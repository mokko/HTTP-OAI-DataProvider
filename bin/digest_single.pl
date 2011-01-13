#!/usr/bin/perl

use strict;
use warnings;
use lib '/home/Mengel/projects/HTTP-OAI-DataProvider/lib';
use HTTP::OAI::DataProvider::SQLite;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Data::Dumper qw/Dumper/;
use utf8;    #for verknupftesObjekt
sub debug;

=head1 NAME

digest_single.pl - store relevant from a single big mpx file into SQLite db

=head1 SYNOPSIS

digest_single.pl file.mpx

=head1 DESCRIPTION

This helper script reads in a big mpx lvl2 file, processes it and stores
relevant information into an SQLite database for use in OAI data provider.
At this point, I am not quite sure how I will call the data provider. See
Salsa_OAI anyways.

For development purposes, this file should have everything that is mpx
specific, so that HTTP::OAI::DataProvider doesn't have any of it. Later,
the mpx specific stuff should go into the Dancer front-end.

=head2 Database Structure

table 1 records
-ID
-identifier
-datestamp
-metadata

table 2 sets
-setSpec
-recordID

=head1 KNOWN ISSUES / TODO

=head2 Missing related info

Currently, this incarnation deals only with the mpx's sammlungobjekt, but the
later xslt will have to access related info from personKörperschaft and multi-
mediaobjekt as well. Hence, we need those two. I should store them in the same
xml blob as the main sammlungsobjekt. This requires rewriting extractRecords.
It no longer can parse sammlungsobjekt by sammlungsobjekt, but needs a
different loop with access to more or less the whole document.

=head2 Wrong package?

Currently, this script is part of HTTP::OAI::DataProvider, but its mpx specific
parts should later go to Dancer front end. When it exists.

=head1 AUTHOR

Maurice Mengel, 2011

=head1 LICENSE

This module is free software and is published under the same
terms as Perl itself.

=head1 SEE ALSO

todo


=cut

#
# user input
#

if ( !$ARGV[0] ) {
	print "Error: Need to specify digest file\n";
	exit 1;
}

if ( !-f $ARGV[0] ) {
	print "Error: Specified digest files does not exist\n";
	print "Try /home/Mengel/projects/Salsa_OAI2/data/fix-test.lvl2.mpx\n";
	exit 1;
}

#todo: outsource configuration to a Dancer config file

my $cache = new HTTP::OAI::DataProvider::SQLite(
	dbfile    => '/home/Mengel/projects/HTTP-OAI-DataProvider/db',
	ns_prefix => 'mpx',
	ns_uri    => 'http://www.mpx.org/mpx',
);

#todo: outsource configuration, see above
my $err = $cache->digest_single(
	source  => $ARGV[0],
	mapping => 'main::extractRecords',
);

if ($err) {
	die $err;
}

#
# SUBS
#

sub debug {
	HTTP::OAI::DataProvider::SQLite::debug @_;
}

=head2 my @records=extractRecords ($doc);

Expects the complete mpx document as dom and returns an array of
HTTP::OAI::Records. Calls setRules on every record to ensure application
OAI sets according to rules defined in setRules.

Todo: What to do on failure?

Todo: Refacturing to separate generation from header and metadata. Done but not
tested.

Todo: Refacturing to include related data (personKörperschaft, multimedia)
in metadata.

Todo: check that set rules are called correctly
You could implement rules which decide on sets if you like.

This mapping should becalled from both import_single and
import_dir.

=cut

sub extractRecords {
	my $self = shift;
	my $doc  = shift;    #old document
	my @records;

	debug "Enter extractRecords ($doc)";

	if ( !$doc ) {
		die "Error: No doc";
	}

	my @nodes = $doc->findnodes('/mpx:museumPlusExport/mpx:sammlungsobjekt');

	my $counter = 0;
	foreach my $node (@nodes) {

		#there can be only one objId
		my @objIds = $node->findnodes('@objId');
		my $objId  = $objIds[0]->value;

		#because xpath issues make md before header
		my $md = $self->main::_mk_md( $doc, $objId );

		#header stuff except sets
		my $header = _extractHeader($node);

		#setRules:mapping set to simple mpx rules
		$node = XML::LibXML::XPathContext->new($node);
		$node->registerNs( $self->{ns_prefix}, $self->{ns_uri} );

		( $node, $header ) = setRules( $node, $header );

		debug "node:" . $node;
		my $record = new HTTP::OAI::Record(
			header   => $header,
			metadata => $md,
		);

		#i could put records in ListRecords or in an array

		#debug 'sdsds'.Dumper $record;

		push @records, $record;

		#debug;
		#if ( ++$counter == 5 ) {
		#	return @records;
		#}

	}
	return @records;

}

#includes the logic of how to extract OAI header information from the node
#expects libxml node (sammlungsobjekt) and returns HTTP::OAI::Header
#is called by extractRecord
sub _extractHeader {
	my $node = shift;

	my @objIds      = $node->findnodes('@objId');
	my $id_orig     = $objIds[0]->value;
	my $id_oai      = 'spk-berlin.de:EM-objId-' . $id_orig;
	my @exportdatum = $node->findnodes('@exportdatum');
	my $exportdatum = $exportdatum[0]->value . 'Z';

	debug "  $id_oai--$exportdatum";
	my $header = new HTTP::OAI::Header(
		identifier => $id_oai,
		datestamp  => $exportdatum,

		#TODO:status=> 'deleted', #deleted or none;
	);

	#debug 'NNNode:' . $node->toString;

	return $header;

}

#expects the whole mpx/xml document as dom and the current id (objId), returns
#metadata for one object including related data (todo) as HTTP::OAI::Metadata
#object
sub _mk_md {
	my $self      = shift;
	my $doc       = shift;    #original doc, a potentially big mpx/xml document
	my $currentId = shift;

	#get root element from original doc
	#speed is not mission critical since this is part of the digester
	#so I don't have to cache this operation
	my @list = $doc->findnodes('/mpx:museumPlusExport');
	if ( !$list[0] ) {
		die "Cannot find root element";
	}

	#make new doc
	my $new_doc = XML::LibXML::Document->createDocument( "1.0", "UTF-8" );

	#add root
	my $root = $list[0]->cloneNode(0);    #0 not deep. It works!
	$new_doc->setDocumentElement($root);

	#get current node
	my @nodes =
	  $doc->findnodes(
		qq(/mpx:museumPlusExport/mpx:sammlungsobjekt[\@objId = '$currentId']));
	my $node = $nodes[0];

	#related info: verknüpftesObjekt
	{
		my $xpath =
		  qw (/mpx:museumPlusExport/mpx:multimediaobjekt)
		  . qq([mpx:verknüpftesObjekt = '$currentId']);

		#debug "DEBUG XPATH $xpath\n";

		my @mume = $doc->findnodes($xpath);
		foreach my $mume (@mume) {

			#debug 'MUME' . $mume->toString . "\n";
			$root->appendChild($mume);
		}
	}

	#related info: personKörperschaft
	{
		my $node   = $self->_registerNS($node);
		my @kueIds = $node->findnodes('mpx:personKörperschaftRef/@id');

		foreach my $kueId (@kueIds) {

			my $id=$kueId->value;

			my $xpath =
			  qw (/mpx:museumPlusExport/mpx:personKörperschaft)
			  . qq([\@kueId = '$id']);
			#debug "DEBUG XPATH $xpath\n";

			my @perKors = $doc->findnodes($xpath);
			foreach my $perKor (@perKors) {

				#debug 'perKor' . $perKor->toString . "\n";
				$root->appendChild($perKor);
			}
		}
	}

	#attach the complete sammlungsdatensatz, there can be only one
	$root->appendChild($node);

	#should I also validate the stuff?

	#MAIN DEBUG
	debug "debug output\n" . $new_doc->toString;

	#wrap into dom into HTTP::OAI::Metadata
	my $md = new HTTP::OAI::Metadata( dom => $new_doc );

	return $md;
}

=head2 $node=setRules ($node);

Gets called during extractRecords for every node (i.e. record) in the xml
source file to map OAI sets to simple criteria on per-node-based
rules.

=cut

sub setRules {
	my $node   = shift;
	my $header = shift;

	#setSpec: MIMO
	my $objekttyp = $node->findvalue('mpx:objekttyp');
	if ($objekttyp) {

		#debug "   objekttyp: $objekttyp\n";
		if ( $objekttyp eq ' Musikinstrument ' ) {
			$header->setSpec(' MIMO ');
			debug "    set setSpect MIMO";
		}
	}

	return $node, $header;
}
