#!/usr/bin/perl

use strict;
use warnings;
use lib '/home/Mengel/projects/HTTP-OAI-DataProvider/lib';
use HTTP::OAI::DataProvider::SQLite;
sub debug;

my $source = '/home/Mengel/projects/Salsa_OAI2/data/fix-test.lvl2.mpx';
my $cache  = new HTTP::OAI::DataProvider::SQLite(
	dbfile    => '/home/Mengel/projects/HTTP-OAI-DataProvider/db',
	ns_prefix => 'mpx',
	ns_uri    => 'http://www.mpx.org/mpx',
);

my $doc = $cache->_loadXML($source);
#debug $doc->toString;
#exit;


#debug 'Continue';
#prepare root
my @list = $doc->findnodes('/mpx:museumPlusExport');
if ( !$list[0] ) {
	die "Cannot find root element";
}



foreach my $node ($doc->findnodes('/mpx:museumPlusExport/mpx:sammlungsobjekt')) {
	debug "reach here";# . $node->toString;

	my $new_doc  = XML::LibXML::Document->createDocument();
	my $root =$list[0]->cloneNode( 0 ); #works!
	$new_doc->setDocumentElement($root);
	$root->appendChild($node);
	my $state=$new_doc->toFile('test.xml', 1);
	debug 'state: '.$state;
	#debug 'lion' . $new_doc->toString;

	#	$old_root->appendChild($node);
	#	debug 'dd'.$old_root->toString;
	exit;

}

#$doc2->documentElement->appendChild( $imported );

#
#$new_dom->setDocumentElement( $old_root );
#debug 'SDSDS:'. $new_dom->toString;
#debug 'owner'.$new_dom->toString;
#$old_root->setOwnerDocument($new_dom->getOwnerDocument() );

#$new_dom->importNode ($old_root);

#debug 'l' . $new_dom->toString;

#debug $doc->documentElement->toString;

sub debug {
	HTTP::OAI::DataProvider::SQLite::debug @_;
}
