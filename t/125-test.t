#!perl

use strict;    #test the test (this is so meta...)
use warnings;
use Test::More tests => 5;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI;
use XML::LibXML;

#use Data::Dumper qw(Dumper); #only for debugging tests
#
# i am testing only the most basic stuff, i.e. if functions succeed
# not testing each and every message, die etc.

{
	my $response = new HTTP::OAI::Identify(
		adminEmail     => 'billig@microsoft.com',
		baseURL        => 'http://www.myarchives.org/oai',
		repositoryName => 'www.myarchives.org',
		granularity    => 'YYYY-MM-DDThh:mm:ssZ',
	);
	okIdentify($response);
}

{
	my $response = testGetRecord();
	okGetRecord($response);
}

{
	my $header = new HTTP::OAI::Header(
		identifier => 'oai:myarchive.org:2233-add',
		datestamp  => '2002-04-12T20:31:00Z',
	);

	my $response = new HTTP::OAI::ListIdentifiers;
	$response->identifier($header);
	okListIdentifiers($response);
}

{
	my $xml = testGetRecord()->toDOM->toString(1);
	ok(
		HTTP::OAI::DataProvider::Test::validateOAIxml( $xml, 'lax' ),
		'lax validatation passes as expected'
	);
	ok( !HTTP::OAI::DataProvider::Test::validateOAIxml($xml),
		'strict validatation fails as expected' );

}

###
### SUBs
###

sub testGetRecord {
	my $xml = '<data xmlns="http://www.test.org">eins</data>';
	#my $xml = '<data>eins</data>';
	my $md  = XML::LibXML->load_xml( string => $xml );
	my $ab  = XML::LibXML->load_xml( string => $xml );

	my $record = new HTTP::OAI::Record();
	$record->header->identifier('oai:myarchive.org:oid-233');
	$record->header->datestamp('2002-04-01');
	$record->header->setSpec('all:novels');
	$record->header->setSpec('all:books');

	$record->metadata( new HTTP::OAI::Metadata( dom => $md ) );
	$record->about( new HTTP::OAI::Metadata( dom => $ab ) );

	my $gr = new HTTP::OAI::GetRecord();
	$gr->record($record);

	return $gr;

}
