#!perl

use Test::More tests => 3;
use HTTP::OAI::DataProvider;
use HTTP::OAI;
use HTTP::OAI::Repository qw(validate_request);
use XML::LibXML;
use FindBin;
#use Data::Dumper qw(Dumper);

#LOAD CONFIG, doesn't work with TAINT mode
my $config = do "$FindBin::Bin/config.pl";
die "options not loaded" if ( !$options );

my $provider = HTTP::OAI::DataProvider->new($options);
my $baseURL  = 'http://localhost:3000/oai';
my %params   = (
	verb           => 'ListIdentifiers',
	metadataPrefix => 'oai_dc',
	set            => 'MIMO',
);

my $error = HTTP::OAI::Repository::validate_request(%params);
if ($error) {
	die "Query error: $error";
}

my $response =
  $provider->ListIdentifiers( $baseURL, %params )
  ;    #response should be a xml string

#print $response;

ok( $response, 'response exists' );
ok( $response =~ /<OAI-PMH/, 'response looks ok' );

my $dom = XML::LibXML->load_xml( string => $response );

my $xpc = XML::LibXML::XPathContext->new($dom);
$xpc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );
my $object =
  $xpc->find('/oai:OAI-PMH/oai:ListIdentifiers/oai:header/oai:identifier');

#print "get here".@object."\n";

ok( $object, '/OAI-PMH/ListIdentifiers/header/identifier exists' );

#diag( "Testing new HTTP::OAI::DataProvider $HTTP::OAI::DataProvider::VERSION, Perl $], $^X" );
