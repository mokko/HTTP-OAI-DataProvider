#!perl

use Test::More tests => 3;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::Repository qw(validate_request);

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

my $provider = HTTP::OAI::DataProvider->new($options);
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



my $dom =
  HTTP::OAI::DataProvider::Test::basicResponseTests($response);    #two tests
print $response;
HTTP::OAI::DataProvider::Test::okIfListRecordMetadataExists($dom);


