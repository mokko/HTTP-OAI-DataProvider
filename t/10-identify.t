#!perl

use strict;
use warnings;
use Test::More tests => 4;
use HTTP::OAI::DataProvider;
use FindBin;
use XML::LibXML;

#use Data::Dumper qw(Dumper);

my %tests =
  { repositoryName => '/oai:OAI-PMH/oai:Identify/oai:repositoryName' };

#LOAD CONFIG, doesn't work with TAINT mode
my $config = do "$FindBin::Bin/test_config" or die "config not loaded";

my $provider = HTTP::OAI::DataProvider->new($config);
my $response = $provider->Identify();    #response should be a xml string

#
# 1 - there is a response
#

ok( $response, 'response exists' );
my $dom = XML::LibXML->load_xml( string => $response );

#
# 2 - response loads in libxml
#

ok( $dom, "dom loads in libxml" );

#print $dom->toString;

#
# 3- response validates against OAI-PMH
#

my $xmlschema =
  XML::LibXML::Schema->new(
	location => 'http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd' )
  or die "Error: Cant parse schema! Might be temporal problem";

eval { $xmlschema->validate($dom); };
ok( !$@, 'document validates against OAI-PMH v2' );

#print "erere$response\n";
#ok( $response =~ /<OAI-PMH/, 'response looks ok' );

#
# 4- check various config values
#

#print $dom->toString;

my $xc = XML::LibXML::XPathContext->new($dom);
$xc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );

foreach my $key (keys %{$tests}){
	ok(
		$config->{$key} eq
		$xc->findvalue($tests->{$key}),
		"$key correct"
	);
  }

