use strict;
use warnings;
use Test::More tests => 3;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use Scalar::Util 'blessed';
use Data::Dumper 'Dumper';
use HTTP::OAI;
use XML::LibXML;

#use Test::XPath;

my $globalFormats = new HTTP::OAI::DataProvider::GlobalFormats();

{
	ok( blessed($globalFormats) eq 'HTTP::OAI::DataProvider::GlobalFormats',
		'globalFormats is globalFormats object' );
}

$globalFormats->register(
	ns_prefix => 'bla',
	ns_uri    => 'http://some.uri.com',
	ns_schema => 'http://some.uri.com/schema.xsd'
) or die "Cant register";

{
	my $list = $globalFormats->{lmf};
	if ( blessed $list ne 'HTTP::OAI::ListMetadataFormats' ) {
		die "Wrong object!";
	}
	ok( $list->metadataFormat->metadataPrefix eq 'bla', 'register works' );
}

$globalFormats->unregister('bla') or die "unregister doesn't succeed";
{
	my $list = $globalFormats->{lmf};
	if ( blessed $list ne 'HTTP::OAI::ListMetadataFormats' ) {
		die "Wrong object!";
	}
	ok (!$list->metadataFormat, 'unregister works');	
}

