#!perl

use Test::More tests => 1;
use HTTP::OAI::DataProvider;
use HTTP::OAI::Repository qw(validate_request);
use HTTP::OAI::DataProvider::Test qw(okListRecords failOnRequestError);

my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);
my $baseURL  = 'http://localhost:3000/oai';
my %params   = (
	verb           => 'ListRecords',
	metadataPrefix => 'mpx',
);

failOnRequestError (%params); #I do want to make sure that params are correct

my $response =  $provider->ListRecords( %params );    #response should be a xml string
okListRecords($response);
#print $response;

