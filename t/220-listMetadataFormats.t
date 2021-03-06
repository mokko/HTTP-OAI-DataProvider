use strict;
use warnings;
use Test::More;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test
  qw/isLMFprefix okListMetadataFormats xpathTester isOAIerror isOAIerror2/;
use Test::XPath;
use XML::LibXML;

# new is taken for granted
my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = HTTP::OAI::DataProvider->new(%config);

plan tests => ( ( keys %{ $config{globalFormats} } ) + 4 );

#
# 1 - ListMetadataFormats without identifier and basic response tests
#
#diag "ListMetadataFormats without identifier";
my $baseURL = 'http://localhost:3000/oai';

{
	#response is HTTP::OAI::Response now
	my $response = $provider->verb( verb => 'ListMetadataFormats' );
	my $xml = $provider->asString($response);
	okListMetadataFormats($response);
	foreach my $prefix ( keys %{ $config{globalFormats} } ) {
		isLMFprefix( $xml, $prefix );
	}
}

{

	#diag "ListMetadataFormats __with__ identifier";
	my $response = $provider->verb(
		verb       => 'ListMetadataFormats',
		identifier => 'spk-berlin.de:EM-objId-543'
	) or die "Cant get metadata format";
	okListMetadataFormats($response);

}
{
	#testing badArgument
	my $response = $provider->verb(
		verb         => 'ListMetadataFormats',
		iddentifiier => 'wrong'
	);
	isOAIerror2( $response, 'badArgument' );

	$response = $provider->verb( 
		verb => 'Identify', 
		Identifier => 'meschugge' );
	isOAIerror2( $response, 'badArgument' );
}

{
	my $response = $provider->verb(
		verb       => 'ListMetadataFormats',
		identifier => 'spk-berlin.de:EM-objId-01234567890A'
	);
	if ($response) {

		#ok ($response=~/idDoesNotExist/, 'idDoesNotExist ok');
		#isOAIerror( $response, 'idDoesNotExist' );
	}
}

#A data provider with global formats cant really respond with noMetadataFormats
#since there are no metadata formats available for the specified item.
