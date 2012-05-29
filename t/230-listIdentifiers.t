#!perl

use Test::More tests => 11;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::Repository qw(validate_request);
use XML::LibXML;
#use Data::Dumper; #debugging the test


#
# $baseURL is not tested since it is deprecated anyway.
#

my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

my $baseURL = 'http://localhost:3000/oai';

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
	);
	validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	okListIdentifiers($response);
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'mpx',
	);
	validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	okListIdentifiers($response, 'different format');
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
	);
	validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	okListIdentifiers($response, 'with set');
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
		'from' => '2011-05-22T02:34:23Z',
	);
	validateRequest(%params);
	
	my $response = $provider->ListIdentifiers( %params );
	okListIdentifiers( $response, 'with from' );
}
{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
		until => '2012-05-22',
	);
	
	validateRequest(%params);

	my $response = $provider->ListIdentifiers( %params );
	okListIdentifiers( $response, 'with until' );
}
{

	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'MIMO',
		'from' => '1900-05-22T02:34:23Z',
		'until' => '2011-05-22T02:34:23Z',
	);
	validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	okListIdentifiers( $response, 'with from and until' );
}

#
# test OAI errors
#
{
	my %params = (
		verb           => 'ListIdentifiers',
		resumptionToken           => 'abc',
	);
	validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	isOAIerror( $response, 'badResumptionToken' );
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'bla',
		set            => 'MIMO',
	);
	validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	isOAIerror( $response, 'cannotDisseminateFormat' );
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		set            => 'MIMO',
	);
	#validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	isOAIerror( $response, 'badArgument' );
}

{
	my %params = (
		verb           => 'ListIdentifiers',
	);
	#validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	isOAIerror( $response, 'badArgument' );
}

{
	my %params = (
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc',
		set            => 'bla',
	);
	#validateRequest(%params);
	my $response = $provider->ListIdentifiers( %params );
	isOAIerror( $response, 'noRecordsMatch' );
}

#TODO: noSetHierarchy

#
#
#
=func validateRequest(%params);

Fails with intelligble error message if %params are not correct. Why test this
here? I need to know that an error is not caused by the params.

Using fail is probably bad style, because it changes the number of tests, but
it gives me an error message in the right color.

Could also be called 
  failOnRequestError (%params);
and be placed in DP::Test
=cut

sub validateRequest {
	if ( my @e = HTTP::OAI::Repository::validate_request(@_) ) {
		fail "Query error: " . $e[0]->code . "\n";
	}
}
