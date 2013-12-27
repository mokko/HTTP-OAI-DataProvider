use strict;
use warnings;
use Test::More;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Common qw(say);
use HTTP::OAI::DataProvider;

my @sequence = (
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc'
	},
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'mpx'
	},
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc'
	},
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'mpx'
	},
	{
		verb           => 'ListRecords',
		metadataPrefix => 'oai_dc'
	},
	{
		verb           => 'ListRecords',
		metadataPrefix => 'mpx'
	},
);

plan tests => scalar @sequence; #put number of tests as early as possible

my %config = loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

my $codeRef = sub {
	my ( $provider, $verb, $params ) = @_;
	my $response=$provider->$verb(%{$params});
	
	if ($provider->error) {
		die "error";
	}
	
	my $xt=xpathTester($provider->asString($response));
	$xt->ok ('/oai:OAI-PMH/*/oai:resumptionToken','resumptionToken exists');
};


testSequence(
	sequence => \@sequence,
	config   => \%config,
	codeRef  => $codeRef
);

