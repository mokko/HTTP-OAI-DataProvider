#!perl

use Test::More tests => 3;
use HTTP::OAI::DataProvider;
use HTTP::OAI::Repository qw(validate_request);
use XML::LibXML;
use FindBin;
#use Data::Dumper qw(Dumper);

#
# init
#

#LOAD CONFIG, doesn't work with TAINT mode
my $config = do "$FindBin::Bin/config.pl";
die "options not loaded" if ( !$options );
my $provider = HTTP::OAI::DataProvider->new($options);

#
# params
#

my $baseURL  = 'http://localhost:3000/oai';
my %params   = (
	verb           => 'GetRecord',
	metadataPrefix => 'mpx',
	identifier     => 'spk-berlin.de:EM-objId-40008',
);

my $error = HTTP::OAI::Repository::validate_request(%params);

#this test is not about query testing, just make sure it works
if ($error) {    
	die "Query error: $error";
}

#
# data provider query
#

my $response =
  $provider->GetRecord( $baseURL, %params );    #response should be a xml string

#print $response;

#
# testing
#

ok( $response, 'response exists' );
ok( $response =~ /<OAI-PMH/, 'response looks ok' );

my $dom = XML::LibXML->load_xml( string => $response );
my $xpc = XML::LibXML::XPathContext->new($dom);
$xpc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );

#print $xpc."\n";

my $object = $xpc->find('/oai:OAI-PMH/oai:GetRecord/oai:record/oai:metadata');

#print $object ."sdsd\n";
ok( $object, '/OAI-PMH/ListIdentifiers/record/metadata exists' );
