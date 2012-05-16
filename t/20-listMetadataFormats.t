use strict;
use warnings;
use Test::More tests => 4;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test qw/basicResponseTests/;
use XML::LibXML;

# new is taken for granted
my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

#
# 1 - ListMetadataFormats without identifier and basic response tests
#
diag "ListMetadataFormats without identifier";
my $baseURL  = 'http://localhost:3000/oai';

my $response =
  $provider->ListMetadataFormats();    #response should be a xml string
#my $response =
#  $provider->ListMetadataFormats($baseURL);    #response should be a xml string

basicResponseTests($response);         #two tests

#TODO: currently ListMetadataFormat fails with wrong error message
#if I leave out the identifier it should say "badArgument", but it says "badVerb"

#TODO: currently ListMetadataFormat fails with or without identifier. THIS IS A BUG!
#param identifier IS OPTIONAL!

#
# 2 - ListMetadataFormats __with__ identifier
#
diag "ListMetadataFormats __with__ identifier";

$response = $provider->ListMetadataFormats(
	identifer => 'spk-berlin.de:EM-objId-1560323' );    #response should be a xml string

basicResponseTests($response);    #two tests
