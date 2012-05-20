#!perl

use Test::More tests => 2;
use HTTP::OAI::DataProvider;
use HTTP::OAI::Repository qw(validate_request);
use HTTP::OAI::DataProvider::Test
  qw(response2dom okValidateOAI okOaiResponse);
use XML::LibXML; #only for debugging

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);
#print "ppppprovider:".$provider."\n";
my $baseURL  = 'http://localhost:3000/oai';

#this test is not about query testing, just make sure it works
my %params   = (verb => 'ListSets');
my $error = HTTP::OAI::Repository::validate_request(%params);

if ($error) {
	die "Query error: $error";
}

#TODO: listSets with resumptionToken

#execute verb: 
#TODO: there is something wrong with the number of params...
my $response =
  $provider->ListSets();    #response should be a xml string
#print $response;

my $dom = response2dom($response);
okValidateOAI($dom);
okOaiResponse($dom);
#print $dom->toString;