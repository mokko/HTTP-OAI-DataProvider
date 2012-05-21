use strict;
use warnings;
use HTTP::OAI::DataProvider::Valid;

#use HTTP::OAI::DataProvider;
use Test::More tests => 4;
use XML::LibXML;
use Slurp; #unnecessary dependency

my $filename = '/home/maurice/projects/HTTP-OAI-DataProvider/xml/getRecord.xml';
die "need file" unless -f $filename;
my $response = slurp ($filename) or die "Cant slurp!";

my $doc = XML::LibXML->load_xml( location => $filename );

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
	my $msg = $v->validateResponse($response, 'lax');
	ok( $msg eq 'ok', "lax validation should pass: $msg" );
}
