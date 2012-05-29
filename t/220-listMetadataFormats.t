use strict;
use warnings;
use Test::More;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test
  qw/isLMFprefix okListMetadataFormats xpathTester isOAIerror/;
use Test::Xpath;
use XML::LibXML;

# new is taken for granted
my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

plan tests => ( ( keys %{ $config{GlobalFormats} } ) + 5 );

#
# 1 - ListMetadataFormats without identifier and basic response tests
#
#diag "ListMetadataFormats without identifier";
my $baseURL = 'http://localhost:3000/oai';

{
	my $response =
	  $provider->ListMetadataFormats();    #response should be a xml string
	okListMetadataFormats($response);

	foreach my $prefix ( keys %{ $config{GlobalFormats} } ) {
		isLMFprefix( $response, $prefix );
	}
}

{

	#diag "ListMetadataFormats __with__ identifier";
	my $response = $provider->ListMetadataFormats(
		identifier => 'spk-berlin.de:EM-objId-1560323' );
	okListMetadataFormats($response);

}

{

	#testing badArgument
	my $response = $provider->ListMetadataFormats( iddentifiier => 'wrong' );
	isOAIerror( $response, 'badArgument' );
	$response = $provider->Identify( identifier => 'meschugge' );
	isOAIerror( $response, 'badArgument' );
}

{
	my $response = $provider->ListMetadataFormats(
		identifier => 'spk-berlin.de:EM-objId-01234567890A' );
	if ( !$response ) {
		isOAIerror( $provider->errorMessage, 'idDoesNotExist' );
	}
}

#DataProvider with globalFormats cant really respond with noMetadataFormats
#(There are no metadata formats available for the specified item.).
