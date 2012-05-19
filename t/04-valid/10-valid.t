use strict;
use warnings;
use HTTP::OAI::DataProvider::Valid;

#use HTTP::OAI::DataProvider;
use Test::More tests => 2;
use XML::LibXML;

my $filename = '/home/maurice/projects/HTTP-OAI-DataProvider/xml/getRecord.xml';
die "need file" unless -f $filename;

my $doc = XML::LibXML->load_xml( location => $filename );

my $v = new HTTP::OAI::DataProvider::Valid();
{
	my $msg = $v->validate($doc);
	ok( $msg ne 'ok', "strict validation fails as expected: $msg" );
}
{
	my $msg = $v->validateLax($doc);
	ok( $msg eq 'ok', "lax validation should pass: $msg" );
}
