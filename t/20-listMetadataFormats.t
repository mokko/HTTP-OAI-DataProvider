use strict;
use warnings;
use Test::More tests => 6;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test
  qw/basicResponseTests response2dom okIfBadArgument/;
use Test::Xpath;
use XML::LibXML;

# new is taken for granted
my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

#
# 1 - ListMetadataFormats without identifier and basic response tests
#
diag "ListMetadataFormats without identifier";
my $baseURL = 'http://localhost:3000/oai';

#TODO: currently ListMetadataFormat WARNS without identifier. THIS IS A BUG!
#param identifier IS OPTIONAL!
{
	my $response =
	  $provider->ListMetadataFormats($baseURL); #response should be a xml string
	basicResponseTests($response);              #two tests
}

{
	diag "ListMetadataFormats __with__ identifier";

	#response should be a xml string
	my $response = $provider->ListMetadataFormats( $baseURL,
		identifier => 'spk-berlin.de:EM-objId-1560323' );
	my $dom = response2dom($response);

	#print $dom->toString;

	basicResponseTests($response);    #two tests
	my $tx = Test::XPath->new(
		xml   => $response,
		xmlns => { oai => 'http://www.openarchives.org/OAI/2.0/' },
	);
#	$dom = response2dom($response);
#	print $dom->toString;
	$tx->ok(
'/oai:OAI-PMH/oai:ListMetadataFormats/oai:metadataFormat/oai:metadataPrefix',
		'metadataPrefix exists'
	);

#test all setLibraries defined default config...
#	foreach my $setSpec ( keys %($config->{setLibrary} ) )
#	  {
#		  $tx->is(
#			  '/oai:OAI-PMH/oai:ListMetadataFormats/oai:metadataFormat/'
#				. 'oai:metadataPrefix',
#			  $setSpec, 'metadataPrefix '.$setSpec.' defined'
#		  );
#	}

#	$dom = response2dom($response);
#	print $dom->toString;
}

  {

	  diag "ListMetadataFormats with badArgument";
	  my $response =
		$provider->ListMetadataFormats( $baseURL, iddentifiier => 'wrong' );
	  my $dom = response2dom($response);

	  okIfBadArgument($dom);
}
