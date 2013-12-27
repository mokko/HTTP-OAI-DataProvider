#!perl

use strict;
use warnings;
use Test::More tests => 9;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use XML::LibXML;
use Test::XPath;


# new is taken for granted
my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

#use Data::Dumper qw(Dumper);
#use Data::Dumper qw(Dumper);
#print Dumper (%config);


my $response = $provider->Identify();    #response should be a xml string
okIdentify($response);
# 1- check config values from test_config
my $from_config_test = {

	#i could save the xpaths in H::O::DP::Test
	repositoryName => '/oai:OAI-PMH/oai:Identify/oai:repositoryName',
	baseURL        => '/oai:OAI-PMH/oai:Identify/oai:baseURL',
	adminEmail     => '/oai:OAI-PMH/oai:Identify/oai:adminEmail',
	deletedRecord  => '/oai:OAI-PMH/oai:Identify/oai:deletedRecord',
};

my $xt = xpathTester($response->toDOM->toString);

foreach my $key ( keys %{$from_config_test} ) {
	$xt->is(
		$from_config_test->{$key},
		$config{identify}{$key},
		"$key correct"
	);
}

# 2 - test static values
my $other_config_values = {
	'request'           => '/oai:OAI-PMH/oai:request',
	'granuality'        => '/oai:OAI-PMH/oai:Identify/oai:granularity',
	'responseDate'      => '/oai:OAI-PMH/oai:responseDate',
	'earliestDatestamp' => '/oai:OAI-PMH/oai:Identify/oai:earliestDatestamp',
};

my $expected = {
	'request'           => 'http://localhost',
	'granuality'        => 'YYYY-MM-DDThh:mm:ssZ',
	'earliestDatestamp' => '2011-02-15T10:03:46Z'

	  #	'responseDate' => '/oai:OAI-PMH/oai:responseDate'
};

foreach my $key ( keys %{$expected} ) {
	$xt->is( $other_config_values->{$key},
		$expected->{$key}, "$key as expected" );
}

#
# 3 test badArgument
#

{
	my $response;
	$response = $provider->Identify( bla => 'meschugge' );
	ok( $response->toDOM->toString =~ /badArgument/, 'right error' );
}

#
# todo: at this point we have just tested if test configuration works as expected
# next we should test if variables change as expected when config is changed

