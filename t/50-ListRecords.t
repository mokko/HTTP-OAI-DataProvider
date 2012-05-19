#!perl

use Test::More tests => 3;
use HTTP::OAI::DataProvider;
use HTTP::OAI::Repository qw(validate_request);
use HTTP::OAI::DataProvider::Test
  qw(response2dom okValidateOAILax okOaiResponse okIfListRecordsMetadataExists);

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);
my $baseURL  = 'http://localhost:3000/oai';
my %params   = (
	verb           => 'ListRecords',
	metadataPrefix => 'mpx',
);

my $error = HTTP::OAI::Repository::validate_request(%params);

#this test is not about query testing, just make sure it works
if ($error) {
	die "Query error: $error";
}

#execute verb
my $response =
  $provider->GetRecord( $baseURL, %params );    #response should be a xml string

#print $response;

my $dom = response2dom($response);
okValidateOAILax($dom);
okOaiResponse($dom);
okIfListRecordsMetadataExists($dom);

