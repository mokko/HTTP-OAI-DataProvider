use strict;
use warnings;
use Test::More;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Common qw(say);
use HTTP::OAI::DataProvider;
use XML::LibXML;
use Data::Dumper qw(Dumper);    #only dor debug

#
# test config
#
my $xpath    = '/oai:OAI-PMH/oai:request';
my @sequence = (
	{ verb => 'Identify' },
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc'
	},
	{ verb => 'ListMetadataFormats' },
	{
		verb           => 'GetRecord',
		identifier     => 'spk-berlin.de:EM-objId-543',
		metadataPrefix => 'oai_dc'
	},
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc'
	},
	{
		verb           => 'ListRecords',
		metadataPrefix => 'oai_dc'
	},
);

plan tests => @sequence * 2 + 3; #put number of tests as early as possible

my $newURL = 'http://somethingelse.com';
my $oldURL = 'http://localhost';


#testing if requestURL can be changed

my $codeRef = sub {
	my ( $provider, $verb, $params ) = @_;

	foreach my $url ( $oldURL, $newURL ) {
		$provider->requestURL($url);
		#$provider->_overwriteRequestURL($url);
		
		my $response = $provider->$verb( %{$params} );

		if ( $provider->OAIerrors->errors ) {
			die "provider error:" . $provider->OAIerrors;
			#fail "oaiError where there should be none";
		}

		my $xt = xpathTester($response);
		#print "$response\n";
		$xt->is( $xpath, $url, "$verb" );
	}

};

#
# let's go
#

my %config = loadWorkingTestConfig();

#say Dumper (%config);

{
	my $provider = new HTTP::OAI::DataProvider(%config);
	ok( !$provider->requestURL, 'no requestURL expected at this point' );
	$provider->requestURL($oldURL);
	ok ($provider->requestURL eq $oldURL, 'setting requestURL to old');
	$provider->requestURL($newURL);
	ok ($provider->requestURL eq $newURL, 'setting requestURL to new');
}

testSequence(
	sequence => \@sequence,
	config   => \%config,
	codeRef  => $codeRef
);

###
### SUBS
###

#not used at the moment
sub showRequestURL {
	my $xt = shift or return;
	print ">>>>>requestURL:" . $xt->xpc->findvalue($xpath) . "!\n";
}

