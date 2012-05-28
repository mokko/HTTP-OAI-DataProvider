use strict;
use warnings;
use Test::More tests => 5;
use FindBin;
use HTTP::OAI::DataProvider::Test;
use Scalar::Util qw(blessed);
use XML::LibXML;

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Transformer') || print "Bail out!
";
}

my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

{
	my %smallConfig = ( nativePrefix => $config{nativePrefix}, );

	eval {
		my $transformer = new HTTP::OAI::DataProvider::Transformer(%smallConfig);
	};
	ok( $@, 'should fail: ' . $@ );
}

{
	my %smallConfig = ( locateXSL => $config{locateXSL}, );

	eval {
		my $transformer = new HTTP::OAI::DataProvider::Transformer(%smallConfig);
	};
	ok( $@, 'should fail: ' . $@ );
}

my %smallConfig = (
	nativePrefix => $config{nativePrefix},
	locateXSL    => $config{locateXSL},
);

my $transformer = new HTTP::OAI::DataProvider::Transformer(%smallConfig);
ok( blessed($transformer) eq 'HTTP::OAI::DataProvider::Transformer',
	'transformer exists' );

{
	my $file = File::Spec->catfile( $FindBin::Bin, 'eg.mpx' );
	my $doc = XML::LibXML->load_xml( location => $file )
	  or die "Cant read file";
	my $newdom = $transformer->toTargetPrefix( 'oai_dc', $doc );
	my $tx = Test::XPath->new(
		xml   => $newdom->toString,
		xmlns => {
			dc     => 'http://purl.org/dc/elements/1.1/',
			oai_dc => 'http://www.openarchives.org/OAI/2.0/oai_dc/'
		  }
	);

	$tx->ok( '/oai_dc:dc/dc:title', 'looks like oai_dc' );
}
