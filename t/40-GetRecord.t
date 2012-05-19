#!perl

use Test::More tests => 2;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::Repository qw(validate_request);
use XML::LibXML;
use FindBin;

#use Data::Dumper qw(Dumper);

#
# init (taken for granted)
#

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

my $baseURL = 'http://localhost:3000/oai';
my %params  = (
	verb           => 'GetRecord',
	metadataPrefix => 'mpx',
	identifier     => 'spk-berlin.de:EM-objId-40008',
);

#this test is not about query testing, just make sure it works
my $error = HTTP::OAI::Repository::validate_request(%params);
die "Query error: $error" if $error;

# execut the verb
my $response =
  $provider->GetRecord( $baseURL, %params );    #response should be a xml string

#
# the actual tests
#

#validation doesn't work well with oai...

my $dom=HTTP::OAI::DataProvider::Test::response2dom ($response);
#$dom->toFile ('getRecord.xml');
HTTP::OAI::DataProvider::Test::okOaiResponse($dom);    

#currently schema validation fails error message: 
#Element '{http://www.mpx.org/mpx}museumPlusExport': No matching global element
#declaration available, but demanded by the strict wildcard.

#print $response;
HTTP::OAI::DataProvider::Test::okIfMetadataExists($dom);
