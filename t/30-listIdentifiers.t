#!perl

use Test::More tests => 6;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;    # qw(basicResponseTests);
use HTTP::OAI::Repository qw(validate_request);
use XML::LibXML;

#use FindBin;
#use Data::Dumper qw(Dumper);

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

my $baseURL = 'http://localhost:3000/oai';
my %params  = (
	verb           => 'ListIdentifiers',
	metadataPrefix => 'oai_dc',
	set            => 'MIMO',
);

my $error = HTTP::OAI::Repository::validate_request(%params);
if ($error) {
	die "Query error: $error";
}

diag "Test with baseURL";
{
	my $response = $provider->ListIdentifiers( $baseURL, %params )
	  ;    #response should be a xml string

	my $dom =
	  HTTP::OAI::DataProvider::Test::basicResponseTests($response);   #two tests
	HTTP::OAI::DataProvider::Test::okIfIdentifierExists($dom);
}


SKIP: {
	skip "Known bug: DataProvider currently doesn't work without baseURL", 3;
	diag "Test without baseURL";
	my $response = $provider->ListIdentifiers(%params)
	  ;    #response should be a xml string

	my $dom =
	  HTTP::OAI::DataProvider::Test::basicResponseTests($response);   #two tests

	HTTP::OAI::DataProvider::Test::okIfIdentifierExists($dom);
}
