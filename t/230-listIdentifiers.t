#!perl

use Test::More tests => 14;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::Repository qw(validate_request);
use XML::LibXML;

#use Data::Dumper; #debugging the test

my $provider = new HTTP::OAI::DataProvider(loadWorkingTestConfig);

##
## OAI responds with verb (no errors)
##

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
	);
	my $response = $provider->verb(%params)
	  or die $provider->error;
	okListIdentifiers($response);
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'mpx',
	);
	my $response = $provider->verb(%params)
	  or die $provider->error;
	okListIdentifiers( $response, 'different format' );
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
	);
	my $response = $provider->verb(%params)
	  or die $provider->error;
	okListIdentifiers( $response, 'with set' );
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
		'from'         => '2011-05-22T02:34:23Z',
	);

	my $response = $provider->verb(%params)
	  or die $provider->OAIerrors;
	okListIdentifiers( $response, 'with from' );
}
{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
		until          => '2012-05-22',
	);

	my $response = $provider->verb(%params)
	  or die $provider->OAIerror;
	okListIdentifiers( $response, 'with until' );
}
{

	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
		'from'         => '1900-05-22T02:34:23Z',
		'until'        => '2011-05-22T02:34:23Z',
	);
	my $response = $provider->verb(%params)
	  or die $provider->error;
	okListIdentifiers( $response, 'with from and until' );
}

##
## test OAI errors
##

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'bla',
		set            => 'MIMO',
	);
	my $response = $provider->verb(%params);
	isOAIerror2( $response, 'cannotDisseminateFormat' );

}

{
	my $response = $provider->OAIerrors;
	if ( $provider->OAIerrors->errors ) {
		isOAIerror2( $response, 'cannotDisseminateFormat' );
		$provider->resetErrorStack;
	}
}

{
	my %params = (
		verb            => 'ListIdentifiers',
		resumptionToken => 'thisIsABadResumptionToken',
	);
	my $response = $provider->verb(%params);
	die "no response" if ( !$response );
	isOAIerror2( $response, 'badResumptionToken' );
	$provider->resetErrorStack;
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'bla',
	);

	my $response = $provider->verb(%params);

	isOAIerror2( $response, 'noRecordsMatch' );
	$provider->resetErrorStack;
}

##
## just two ways to cause badArgument
##

{
	my %params = (
		verb => 'ListIdentifiers',
		set  => 'MIMO',              #metadataPrefix missing
	);

	my $response = $provider->verb(%params);

	#test return value
	isOAIerror2( $response, 'badArgument' );

	#test provider error
	if ( $provider->error ) {
		$response = $provider->OAIerrors;
		#ok ($response->toDOM->toString =~/badArgument/, 'badArgument' );
		isOAIerror2( $response, 'badArgument' );
		$provider->resetErrorStack;
	}
}

{
	my %params = ( verb => 'ListIdentifiers', );

	my $response = $provider->verb(%params);
	isOAIerror2( $response, 'badArgument' );
	if ( $provider->error ) {
		$response = $provider->OAIerrors;
		#ok ($response->toDOM->toString =~/badArgument/, 'badArgument' );
		isOAIerror2( $response, 'badArgument' );
		$provider->resetErrorStack;
	}
}

#TODO: noSetHierarchy

