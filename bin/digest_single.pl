#!/usr/bin/perl

use strict;
use warnings;
use lib '/home/Mengel/projects/HTTP-OAI-DataProvider/lib';
use HTTP::OAI::DataProvider::SQLite;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Data::Dumper qw/Dumper/;
sub debug;

my $cache = new HTTP::OAI::DataProvider::SQLite(
	dbfile    => '/home/Mengel/projects/HTTP-OAI-DataProvider/db',
	ns_prefix => 'mpx',
	ns_uri    => 'http://www.mpx.org/mpx',
);

my $err = $cache->digest_single(
	source  => '/home/Mengel/projects/Salsa_OAI2/data/fix-test.lvl2.mpx',
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

=head2 my @headers=extractHeader ($doc);

OUTDATED VERSION! USE EXTRACTRECORDS INSTEAD FOR DATABASE VERSION AT LEAST

Mapping which extracts headers from a source document. Implement your own
method if you want. It gets a LibXML document (or xpath) as in input and
outputs an array of HTTP::OAI::Headers.

You could implement rules which decide on sets if you like.

This mapping should becalled from both import_single and
import_dir.

=cut

sub extractHeaders {
	my $self = shift;
	my $doc  = shift;
	my @result;

	debug "Enter extractHeader ($doc)";

	if ( !$doc ) {
		die "Error: No doc";
	}

	my @nodes = $doc->findnodes('/mpx:museumPlusExport/mpx:sammlungsobjekt');

	my $counter = 0;
	foreach my $node (@nodes) {
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

		$node = XML::LibXML::XPathContext->new($node);
		$node->registerNs( $self->{ns_prefix}, $self->{ns_uri} );

		#mapping set to simple mpx rules
		( $node, $header ) = setRules( $node, $header );

		push @result, $header;

		#debug;
		if ( ++$counter == 5 ) {
			return @result;
		}

	}
	return @result;

	#TODO: actually I should return a full record including md
	#my $r = new HTTP::OAI::Record();

	#$r->header->identifier('oai:myarchive.org:oid-233');
	#$r->header->datestamp('2002-04-01');
	#$r->header->setSpec('all:novels');
	#$r->header->setSpec('all:books');

	#$r->metadata(new HTTP::OAI::Metadata(dom=>$md));
	#$r->about(new HTTP::OAI::Metadata(dom=>$ab));
}

=head2 my @records=extractRecords ($doc);

Mapping which extracts headers from a source document. Implement your own
method if you want. It gets a LibXML document (or xpath) as in input and
outputs an array of HTTP::OAI::Headers.

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

	my @list = $doc->findnodes('/mpx:museumPlusExport');
	if ( !$list[0] ) {
		die "Cannot find root element";
	}
	my @nodes = $doc->findnodes('/mpx:museumPlusExport/mpx:sammlungsobjekt');

	my $counter = 0;
	foreach my $node (@nodes) {
		my $new_doc = XML::LibXML::Document->createDocument( "1.0", "UTF-8" );
		my $root    = $list[0]->cloneNode(0);#0 not deep. It works!
		$new_doc->setDocumentElement($root);
		$root->appendChild($node);

		#debug "sd:" . $new_doc->toString;

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

		my $md = new HTTP::OAI::Metadata( dom => $new_doc );

		$node = XML::LibXML::XPathContext->new($node);
		$node->registerNs( $self->{ns_prefix}, $self->{ns_uri} );

		#mapping set to simple mpx rules
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
		if ( ++$counter == 5 ) {
			return @records;
		}

	}
	return @records;

}

=head2 $node=setRules ($node);

Gets called during extractHeaders for every node (i.e. record) in the xml
source file. The idea is to map OAI sets to simple criteria on per-node-based
rules.

=cut

sub setRules {
	my $node   = shift;
	my $header = shift;

	#setSpec: MIMO
	my $objekttyp = $node->findvalue('mpx:objekttyp');
	if ($objekttyp) {

		#debug "   objekttyp: $objekttyp\n";
		if ( $objekttyp eq 'Musikinstrument' ) {
			$header->setSpec('MIMO');
			debug "    set setSpect MIMO";
		}
	}

	return $node, $header;
}
