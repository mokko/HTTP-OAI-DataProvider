#!perl

use strict;
use warnings;
use Test::More tests => 9;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test qw(xpathTester okIdentify okIfBadArgument);
use XML::LibXML;
use Test::Xpath;

#use Data::Dumper qw(Dumper);

# new is taken for granted
my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

#
# execute verb: test if things work
#
my $response = $provider->Identify();    #response should be a xml string
okIdentify($response);

#
# 1- check config values from test_config
#

#i could save the xpath in H::O::DP::Test
#will do so once I need it repeatedly
my $from_config_test = {
	repositoryName => '/oai:OAI-PMH/oai:Identify/oai:repositoryName',
	baseURL        => '/oai:OAI-PMH/oai:Identify/oai:baseURL',
	adminEmail     => '/oai:OAI-PMH/oai:Identify/oai:adminEmail',
	deletedRecord  => '/oai:OAI-PMH/oai:Identify/oai:deletedRecord',
};

my $tx = xpathTester($response);

foreach my $key ( keys %{$from_config_test} ) {
	$tx->is( $from_config_test->{$key}, $config->{$key}, "$key correct" );
}

#
# 2 - test static values
#

my $other_config_values = {
	'request'           => '/oai:OAI-PMH/oai:request',
	'granuality'        => '/oai:OAI-PMH/oai:Identify/oai:granularity',
	'responseDate'      => '/oai:OAI-PMH/oai:responseDate',
	'earliestDatestamp' => '/oai:OAI-PMH/oai:Identify/oai:earliestDatestamp',
};

my $expected = {
	'request'           => 'http://localhost',
	'granuality'        => 'YYYY-MM-DDThh:mm:ssZ',
	'earliestDatestamp' => '2010-04-20T11:21:49Z'

	  #	'responseDate' => '/oai:OAI-PMH/oai:responseDate'
};

foreach my $key ( keys %{$expected} ) {
	$tx->is( $other_config_values->{$key},
		$expected->{$key}, "$key as expected" );
}

#
# 3 test badArgument
#

{
	my $response = $provider->Identify( bla => 'meschugge', 1 )
	  ;    #response should be a xml string
	okIfBadArgument($response);
}

#
# todo: at this point we have just tested if test configuration works as expected
# next we have to test if various function/change as expected when config is changed

