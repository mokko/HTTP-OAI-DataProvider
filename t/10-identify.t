#!perl

use strict;
use warnings;
use Test::More tests => 10;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use FindBin;
use XML::LibXML;

#use Data::Dumper qw(Dumper);

my $config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

my $from_config_test = {
	repositoryName => '/oai:OAI-PMH/oai:Identify/oai:repositoryName',
	baseURL        => '/oai:OAI-PMH/oai:Identify/oai:baseURL',
	adminEmail     => '/oai:OAI-PMH/oai:Identify/oai:adminEmail',
	deletedRecord  => '/oai:OAI-PMH/oai:Identify/oai:deletedRecord',
};

#
# new is taken for granted
#

my $provider = new HTTP::OAI::DataProvider($config);

#
# 1 - verb gets a response
#

my $response = $provider->Identify();    #response should be a xml string
ok( $response, 'response exists' );

#
# 2 - response loads in libxml
#

my $dom = XML::LibXML->load_xml( string => $response );
ok( $dom, "dom loads in libxml" );

#print $dom->toString;

#
# 3- response validates against OAI-PMH
#

my $xmlschema =
  XML::LibXML::Schema->new(
	location => 'http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd' )
  or die "Error: Cant parse schema! Might be temporal problem";

eval { $xmlschema->validate($dom); };
ok( !$@, 'document validates against OAI-PMH v2' );

#
# 4- check config values from test_config
#

#print $dom->toString(2);

my $xc = XML::LibXML::XPathContext->new($dom);
$xc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );

foreach my $key ( keys %{$from_config_test} ) {
	ok( $config->{$key} eq $xc->findvalue( $from_config_test->{$key} ),
		"$key correct" );
}

#
# 5 - test other identify values with static values 
#

my $other_config_values = {
	'request'      => '/oai:OAI-PMH/oai:request',
	'granuality'   => '/oai:OAI-PMH/oai:Identify/oai:granularity',
	'responseDate' => '/oai:OAI-PMH/oai:responseDate', 
	'earliestDatestamp' => '/oai:OAI-PMH/oai:Identify/oai:earliestDatestamp', 
};


my $expected = {
	'request'    => 'http://localhost',
	'granuality' => 'YYYY-MM-DDThh:mm:ssZ',
	'earliestDatestamp' => '2010-04-20T11:21:49Z'

	#	'responseDate' => '/oai:OAI-PMH/oai:responseDate'
};

foreach my $key ( keys %{$expected} ) {
	my $value=$xc->findvalue( $other_config_values->{$key});
	ok( $value eq $expected->{$key}, 
		"$key as expected"  
	);
	#print "|$value| eq |".$expected->{$key}."|?\n";
}

#
# todo: at this point we have just tested if test configuration works as expected
# next we have to test if various function/change as expected when config is changed
