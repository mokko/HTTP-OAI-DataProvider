use strict;
use warnings;
use Test::More;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Common qw(hashRef2hash say);
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
		identifier     => 'spk-berlin.de:EM-objId-40008',
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

plan tests => @sequence * 2 + 1;

#
# let's go
#

my $provider = new HTTP::OAI::DataProvider(loadWorkingTestConfig);

ok( !$provider->requestURL, 'no requestURL expected at this point' );

my $newURL = 'http://somethingelse.com';
my $oldURL = 'http://localhost';

foreach my $params (@sequence) {
	my $verb = $params->{verb};
	delete( $params->{verb} );

	#say "v:$verb";
	#say Dumper ($params);

	#first time
	my $response = $provider->$verb( %{$params} )
	  or say $provider->error;
	my $xt = xpathTester($response);
	$xt->is( $xpath, $oldURL, 'expect localhost' );

	#2nd time
	$provider->requestURL($newURL);
	$response = $provider->$verb( %{$params} )
	  or say $provider->error;
	$xt = xpathTester($response);
	$xt->is( $xpath, $newURL, 'expect localhost' );

}

###
### SUBS
###
sub showRequestURL {
	my $xt = shift or return;
	print ">>>>>requestURL:" . $xt->xpc->findvalue($xpath) . "!\n";
}

=head2 testSequence (%opts);

my @sequence = (
	{ verb => 'Identify' },
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc'
	}
);

$codeRef=sub {
	my ($provider, $verb, $params)=@_;
	my $response = $provider->$verb( %{$params} );
	ok ($response, 'response exists');
};

testSequence (
	config=>\%config, 
	sequence=>\@sequence, 
	codeRef=>$codeRef
);

=cut

sub testSequence {
	my %opts = @_;

	my @sequence = @{ $opts{sequence} };

	my $provider = new HTTP::OAI::DataProvider( %{ $opts{config} } );

	foreach my $params (@sequence) {
		my $verb = $params->{verb};
		delete( $params->{verb} );

		$opts{codeRef}( $provider, $verb, $params );
	}
}

