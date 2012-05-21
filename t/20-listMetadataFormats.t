use strict;
use warnings;
use Test::More;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test
  qw/isLMFprefix okIfBadArgument okListMetadataFormats xpathTester isOAIerror/;
use Test::Xpath;
use XML::LibXML;

# new is taken for granted
my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

plan tests => ( keys( %{ $config->{GlobalFormats} } ) + 5 );

#
# 1 - ListMetadataFormats without identifier and basic response tests
#
#diag "ListMetadataFormats without identifier";
my $baseURL = 'http://localhost:3000/oai';

#TODO: currently ListMetadataFormat WARNS without identifier. THIS IS A BUG!
#param identifier IS OPTIONAL!

{
	my $response =
	  $provider->ListMetadataFormats($baseURL); #response should be a xml string
	okListMetadataFormats($response);

	foreach my $prefix ( keys %{ $config->{GlobalFormats} } ) {
		isLMFprefix( $response, $prefix );
	}
}

{

	#diag "ListMetadataFormats __with__ identifier";
	my $response = $provider->ListMetadataFormats( $baseURL,
		identifier => 'spk-berlin.de:EM-objId-1560323' );
	okListMetadataFormats($response);

}

{

	#testing badArgument
	#diag "ListMetadataFormats with badArgument";
	my $response =
	  $provider->ListMetadataFormats( $baseURL, iddentifiier => 'wrong' );
	okIfBadArgument($response);
	$response = $provider->Identify( 1, identifier => 'meschugge' );
	okIfBadArgument($response);
}

{
	my $response =
	  $provider->ListMetadataFormats( $baseURL, identifier => 'spk-berlin.de:EM-objId-01234567890A' );
	isOAIerror( $response, 'idDoesNotExist' );
}

#DataProvider with globalFormats cant really respond with noMetadataFormats.
