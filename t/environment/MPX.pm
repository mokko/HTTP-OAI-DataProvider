package MPX;
# ABSTRACT: MPX-specific extensions

use strict;
use warnings;
use utf8;    #for verknupftesObjekt
use XML::LibXML;
use XML::LibXML::XPathContext;
use HTTP::OAI::DataProvider::Common qw(Debug);

=head2 my @records=$self->extractRecords ($doc);

Expects an mpx document as dom and returns an array of HTTP::OAI::Records. Gets
called from digest_single.

=cut

sub extractRecords {
	my $self = shift;
	my $doc  = shift;    #old document

	#Debug "Enter extractRecords!";

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
		#my $md = $self->_mk_md( $doc, $objId );
		my $md = $self->MPX::_mk_md( $doc, $objId );

		#complete header including sets
		my $header = $self->MPX::extractHeader($node);

		#Debug "node:" . $node;
		my $record = new HTTP::OAI::Record(
			header   => $header,
			metadata => $md,
		);
		return $record;
	}
}


=head2 my $header=extractHeader ($node);

#includes the logic of how to extract OAI header information from the node
#expects libxml node (sammlungsobjekt) and returns HTTP::OAI::Header
#is called by extractRecord

extractHeader is a function, not a method. It expects a XML::LibXML object.
(I am not sure which. Maybe XML::LibXML::Node) and returns a complete
HTTP::OAI::Header. (I emphasize complete, because an earlier version did not
deal with sets.) This FUNCTION gets called from extractRecord, but also from
DataProvider::$Engine::findByIdentifier

=cut

sub extractHeader {
	my $self = shift;
	my $node = shift;

	my @objIds      = $node->findnodes('@objId');
	my $id_orig     = $objIds[0]->value;
	my $id_oai      = 'spk-berlin.de:EM-objId-' . $id_orig;
	my @exportdatum = $node->findnodes('@exportdatum');
	my $exportdatum = $exportdatum[0]->value . 'Z';

	#Debug "  $id_oai--$exportdatum";
	my $header = new HTTP::OAI::Header(
		identifier => $id_oai,
		datestamp  => $exportdatum,
		#TODO:status=> 'deleted', #deleted or none;
	);

	( $node, $header ) = $self->MPX::setRules( $node, $header );

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
	my @nodes = $doc->findnodes(
		qq(/mpx:museumPlusExport/mpx:sammlungsobjekt[\@objId = '$currentId']));
	my $node = $nodes[0];

	#related info: verknüpftesObjekt
	{
		my $xpath = qw (/mpx:museumPlusExport/mpx:multimediaobjekt)
		  . qq([mpx:verknüpftesObjekt = '$currentId']);

		#Debug "Debug XPATH $xpath\n";

		my @mume = $doc->findnodes($xpath);
		foreach my $mume (@mume) {

			#Debug 'MUME' . $mume->toString . "\n";
			$root->appendChild($mume);
		}
	}

	#related info: personKörperschaft
	{
		my $node   = $self->registerNS($node);
		my @kueIds = $node->findnodes('mpx:personKörperschaftRef/@id');

		foreach my $kueId (@kueIds) {

			my $id = $kueId->value;

			my $xpath = qw (/mpx:museumPlusExport/mpx:personKörperschaft)
			  . qq([\@kueId = '$id']);

			#Debug "Debug XPATH $xpath\n";

			my @perKors = $doc->findnodes($xpath);
			foreach my $perKor (@perKors) {

				#Debug 'perKor' . $perKor->toString . "\n";
				$root->appendChild($perKor);
			}
		}
	}

	#attach the complete sammlungsdatensatz, there can be only one
	$root->appendChild($node);

	#should I also validate the stuff?

	#MAIN Debug
	#Debug "Debug output\n" . $new_doc->toString;

	#wrap into dom into HTTP::OAI::Metadata
	my $md = new HTTP::OAI::Metadata( dom => $new_doc );

	return $md;
}


=method my ($node, $header) = setRules ($node, $header);

Gets called during extractRecords for every node (i.e. record) in the xml
source file to map OAI sets to simple criteria on per-node-based
rules. Returns node and header. Header can have multiple sets

=cut

sub setRules {
	my $self   = shift;
	my $node   = shift;
	my $header = shift;

	#Debug "Enter setRules";

	#setRules:mapping set to simple mpx rules
	$node = XML::LibXML::XPathContext->new($node);
	$node->registerNs( $self->{nativePrefix}, $self->{nativeURI} );

	#for testing the setSpec test and setSpecs in general
	#$header->setSpec('test');
	#Debug "    set setSpec 'test'";

	#setSpec: MIMO
	my $objekttyp = $node->findvalue('mpx:objekttyp');
	if ($objekttyp) {

		#Debug "   objekttyp: $objekttyp\n";
		if ( $objekttyp eq 'Musikinstrument' ) {
			my $setSpec = 'MIMO';
			$header->setSpec($setSpec);
			#Debug "    set setSpec '$setSpec'";
		}
	}

	my $sachbegriff = $node->findvalue('mpx:sachbegriff');
	if ($sachbegriff) {

		#Debug "   objekttyp: $objekttyp\n";
		if ( $sachbegriff eq 'Schellackplatte' ) {
			my $setSpec = '78';
			$header->setSpec($setSpec);
			Debug "    set setSpec '$setSpec'";
		}
	}
	return $node, $header;
}

#
# not sure where this should go. It is not strictly speaking mpx, but it belongs
# to transformation.


sub locateXSL {
#	my $prefix       = shift;
#	my $nativeFormat = config->{nativePrefix};
#	$nativeFormat
#	  ? return config->{XSLT_dir} . '/'
#	  . $nativeFormat . '2'
#	  . $prefix
#	  . '.xsl'
#	  : return ();
}

1;



