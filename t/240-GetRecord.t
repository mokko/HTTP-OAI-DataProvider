#!perl

use Test::More tests => 6;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use XML::LibXML;
use FindBin;

#use Data::Dumper qw(Dumper);

#
# init (taken for granted)
#

my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

my $baseURL = 'http://localhost:3000/oai';

#
# the actual tests
# 1-see if it works
{
	my %params = (
		metadataPrefix => 'mpx',
		identifier     => 'spk-berlin.de:EM-objId-40008',
	);
	my $response = $provider->GetRecord( %params );
	okGetRecord($response);
}

#
# 2-OAI errors
#

{
	my %params = ( identifier => 'spk-berlin.de:EM-objId-40008', );
	my $response = $provider->GetRecord( %params );
	isOAIerror($response, 'badArgument');
}

{
	my %params = ( metadataPrefix => 'mpx', );
	my $response = $provider->GetRecord( %params );
	isOAIerror($response, 'badArgument');
}

{
	my %params = (
		metadataPrefix => 'mpx',
		identifier     => 'spk-berlin.de:EM-objId-40008',
		meschugge      => 'schixe',
	);
	my $response = $provider->GetRecord( %params );
	isOAIerror($response, 'badArgument');
}

{
	my %params = (
		metadataPrefix => 'mpx',
		identifier     => 'spk-berlin.de:EM-objId-meschugge',
	);
	my $response = $provider->GetRecord( %params );
	isOAIerror($response, 'idDoesNotExist');
}

{
	my %params = (
		metadataPrefix => 'meschugge',
		identifier     => 'spk-berlin.de:EM-objId-40008',
	);
	my $response = $provider->GetRecord( %params );
	isOAIerror($response, 'cannotDisseminateFormat');
}
 

