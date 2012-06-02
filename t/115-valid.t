use strict;
use warnings;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Valid;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Common qw(say);
use Test::More tests => 4;
use XML::LibXML;
use File::Spec;

#at this point the provider is not yet tested, so I should be using it really
#in older versions I loaded a OAI response from file for that reason
my %config   = loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);
my $response = $provider->GetRecord(
	metadataPrefix => 'oai_dc',
	identifier     => 'spk-berlin.de:EM-objId-524'
) or die "Cant identify";

my $doc = XML::LibXML->load_xml( string => $response )
  or die "Cant load xml response!";

my $v = new HTTP::OAI::DataProvider::Valid();

#old form
{
	my $msg = $v->validate($doc);
	ok( $msg ne 'ok', "strict validation fails as expected: $msg" );
}
{
	my $msg = $v->validateLax($doc);
	ok( $msg eq 'ok', "lax validation should pass: $msg" );
}

#new form
{
	my $msg = $v->validateResponse($response);
	ok( $msg ne 'ok', "strict validation fails as expected: $msg" );
}

{
	my $msg = $v->validateResponse( $response, 'lax' );
	ok( $msg eq 'ok', "lax validation should pass: $msg" );
}
