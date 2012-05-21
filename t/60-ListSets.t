#!perl

use Test::More tests => 1;
use HTTP::OAI::DataProvider;
use HTTP::OAI::Repository qw(validate_request);
use HTTP::OAI::DataProvider::Test qw(okListSets);
use XML::LibXML;                                     #only for debugging

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

#print "ppppprovider:".$provider."\n";
my $baseURL = 'http://localhost:3000/oai';

#this test is not about query testing, just make sure it works
my %params = ( verb => 'ListSets' );
my $error = HTTP::OAI::Repository::validate_request(%params);

if ($error) {
	die "Query error: $error";
}

#TODO: listSets with resumptionToken

#execute verb:
#TODO: there is something wrong with the number of params...
#response should be a xml string
print "EINS\n";    
my $response = $provider->ListSets();
print "HERE\n";    
okListSets($response);
#print $response;
