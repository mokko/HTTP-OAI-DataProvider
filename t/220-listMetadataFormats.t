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

plan tests => ( ( keys %{ $config{globalFormats} } ) + 4 );

#
# 1 - ListMetadataFormats without identifier and basic response tests
#
#diag "ListMetadataFormats without identifier";
my $baseURL = 'http://localhost:3000/oai';

{
	my $response =
	  $provider->ListMetadataFormats();    #response should be a xml string
	  	okListMetadataFormats($response);

	foreach my $prefix ( keys %{ $config{globalFormats} } ) {
		isLMFprefix( $response, $prefix );
	}
}

{

	#diag "ListMetadataFormats __with__ identifier";
	my $response = $provider->ListMetadataFormats(
		identifier => 'spk-berlin.de:EM-objId-153740' ) or die "Cant get metadata format";
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
	if ( $response ) {
		#print $provider->error;
		isOAIerror( $provider->error, 'idDoesNotExist' );
	}
}

#DataProvider with globalFormats cant really respond with noMetadataFormats
#(There are no metadata formats available for the specified item.).
