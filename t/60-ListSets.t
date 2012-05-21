#!perl

use Test::More tests => 1;
use HTTP::OAI::DataProvider;
use HTTP::OAI::Repository qw(validate_request);
use HTTP::OAI::DataProvider::Test qw(okListSets isSetSpec);
use XML::LibXML;    #only for debugging

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

#print "ppppprovider:".$provider."\n";
my $baseURL = 'http://localhost:3000/oai';

#this test is not about query testing, just make sure it works
my %params = ( verb => 'ListSets' );
my $error = HTTP::OAI::Repository::validate_request(%params);

if ($error) {
	die "Query error: $error";
}

#TODO:
##listSets with resumptionToken
##there is something wrong with the number of params?

#execute verb:
my $response = $provider->ListSets(1);
okListSets($response);

TODO: {
	local $TODO= 'some time in the future';

	#test all setLibraries defined default config...
	#print "$response";
	my $setLibrary = $config->{setLibrary};
	foreach my $setSpec ( keys %{$setLibrary} ) {
		my $setName = $setLibrary->{$setSpec}->{setName};
		my $setDesc = $setLibrary->{$setSpec}->{setDescription};

		#isSetSpec( $response, $setSpec );
		if ($setName) {

			#print "\t$setName\n";
			#isSetName (response=>$reponse,setSpec=>$setSpec, setName=>$setName,
			#msg=>'setName $setName exists');
		}
		if ($setDesc) {

			#print "\t$setDesc\n";
			#isSetDesc ($reponse,$setDesc, 'setDesc $setDesc exists');
		}
	}

}

