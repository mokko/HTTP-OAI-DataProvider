#!perl

use Test::More tests => 7;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use XML::LibXML;
use FindBin;

use Data::Dumper qw(Dumper);

#
# init (taken for granted)
#

my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

my $baseURL = 'http://localhost:3000/oai';

#
# the actual tests
# 1-see if simple GetRecord works
{
	my %params = (
		verb           => 'GetRecord',
		metadataPrefix => 'mpx',
		identifier     => 'spk-berlin.de:EM-objId-524',
	);
	my $response = $provider->verb(%params);
	okGetRecord($response);
	$provider->resetErrorStack;
}

#
# 2-OAI errors: see if it fails as expected
#

{
	my %params = (
		identifier => 'spk-berlin.de:EM-objId-40008',
		verb       => 'GetRecord',
	);
	my $response = $provider->verb(%params);
	isOAIerror( $provider->asString($response), 'badArgument' );
	$provider->resetErrorStack;
}

{
	my %params = (
		metadataPrefix => 'mpx',
		verb           => 'GetRecord',
	);
	my $response = $provider->verb(%params);
	isOAIerror2( $response, 'badArgument' );
	$provider->resetErrorStack;

}

{
	my %params = (
		verb           => 'GetRecord',
		metadataPrefix => 'mpx',
		identifier     => 'spk-berlin.de:EM-objId-40008',
		meschugge      => 'schixe',
	);
	my $response = $provider->verb(%params);
	isOAIerror2( $response, 'badArgument' );
	$provider->resetErrorStack;
}

{
	my %params = (
	verb=>'GetRecord',
		metadataPrefix => 'mpx',
		identifier     => 'spk-berlin.de:EM-objId-meschugge',
	);
	my $response = $provider->verb(%params);
	isOAIerror2( $response, 'idDoesNotExist' );

}

{
	#make sure that this id exists!
	my %params = (
		verb=> 'GetRecord',
		metadataPrefix => 'meschugge',
		identifier     => 'spk-berlin.de:EM-objId-524',
	);
	my $response = $provider->verb(%params);
	isOAIerror2( $response, 'cannotDisseminateFormat' );
	isOAIerror2( $response, 'cannotDisseminateFormat' );

}

