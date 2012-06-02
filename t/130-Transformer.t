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

my %engine = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig('engine');
my %nativeFormat =
  HTTP::OAI::DataProvider::Test::loadWorkingTestConfig('nativeFormat');
my $nativePrefix = ( keys(%nativeFormat) )[0];

#print "native:$nativePrefix\n";
#my $nativeURI=$nativeFormat{$nativePrefix};

{
	eval {
		my $transformer =
		  new HTTP::OAI::DataProvider::Transformer(
			nativePrefix => $nativePrefix );
	};
	ok( $@, 'should fail ' );
}

{

	eval {
		my $transformer =
		  new HTTP::OAI::DataProvider::Transformer(
			locateXSL => $engine{locateXSL} );
	};
	ok( $@, 'should fail ' );
}

#
# finally make a transformer
#

my $transformer = new HTTP::OAI::DataProvider::Transformer(
	nativePrefix => $nativePrefix,
	locateXSL    => $engine{locateXSL},
);

ok( blessed($transformer) eq 'HTTP::OAI::DataProvider::Transformer',
	'transformer exists' );

{
	my $file = testEnvironment( 'dir', 'eg.mpx' );

	#print "FILE: $file\n";
	my $doc = XML::LibXML->load_xml( location => $file )
	  or die "Cant read file";
	my $newdom = $transformer->toTargetPrefix( 'oai_dc', $doc );

	#print $newdom->toString;
	my $tx = Test::XPath->new(
		xml   => $newdom->toString,
		xmlns => {
			dc     => 'http://purl.org/dc/elements/1.1/',
			oai_dc => 'http://www.openarchives.org/OAI/2.0/oai_dc/'
		}
	);

	$tx->ok( '/oai_dc:dc/dc:title', 'looks like oai_dc works' );
}
