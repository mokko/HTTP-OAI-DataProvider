#!perl 
#-T

use strict;
use warnings;
use Test::More tests => 14;
use HTTP::OAI;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Transformer;
use Scalar::Util qw(blessed);

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Engine::Result') || print "Bail out!
";
}

#
# preparations
#

my %engine       = loadWorkingTestConfig('engine');
my %nativeFormat = loadWorkingTestConfig('nativeFormat');
my $nativePrefix = ( keys(%nativeFormat) )[0];

#print "prefix:$nativePrefix\n";

my $t = new HTTP::OAI::DataProvider::Transformer(
	nativePrefix => $nativePrefix,
	locateXSL    => $engine{locateXSL},
) or die "Cant make transformer";

#
# 1-test new
#

eval {
	my $result =
	  new HTTP::OAI::DataProvider::Engine::Result( transformer => $t );
};
ok( $@, 'should fail: ' );

eval {
	my $result =
	  new HTTP::OAI::DataProvider::Engine::Result( verb => 'GetRecord' );
};
ok( $@, 'should fail: ' );

my $result = minimalResult();
ok( blessed($result) eq 'HTTP::OAI::DataProvider::Engine::Result',
	'minimal new works' );


#
# 2-$result->requestURL
#

my $url = $result->requestURL();    #getter
ok( !$url, 'url doesn\'t exist' );

$url = $result->requestURL('http://some.uri.com') or die "Wrong!";    #setter
ok( $url eq 'http://some.uri.com', 'url exists now' );

$url = $result->requestURL();                                         #getter
ok( $url eq 'http://some.uri.com', 'url exists now' );

#
# 3-$result->addError($code[, $message]);
# 4-$result->isError()
#

ok( !$result->isError, 'isError should return nothing' );

eval { $result->addError('nonsense'); };
ok( $@, 'should fail' );

$result->addError('badArgument');
ok( $result->addError('badArgument'), 'adds error and returns true' );

ok( $result->isError, 'isError should return true' );

my @err = $result->isError();
ok( $err[0]->code eq 'badArgument', 'isError contains right HTTP::OAI error' );

#
# 5-$result->countHeaders()
#

$result = minimalResult();
ok( $result->countHeaders() == 0, "head count is zero" );

#TODO see if it changes DO WE REALLY NEED CHUNK SIZE METHOD INSIDE OF RESULT?
#Can it not be elsewhere?

#
# 6-$result->chunkSize
#
#{
#	my %engine = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig('engine');
#	#die "Need chunkSize" if ( !$config{chunkSize} );
#
#	print "CHUNK SIZE:$engine{chunkCache}{RecordsPerChunk}\n";
#
#	my %opts = (
#		transformer => $t,
#		verb        => 'GetRecord',
#		chunkSize   => $engine{chunkCache}{RecordsPerChunk},
#	);
#	$result = new HTTP::OAI::DataProvider::Engine::Result(%opts);
#	new HTTP::OAI::DataProvider::Engine::Result(%opts);
#	ok( $result->chunkSize == $engine{chunkCache}{RecordsPerChunk}, 'chunkSize seems right' );
#}

#
# 7-$result->getType();
#

#ok( $result->getType(), '$r->getType is weird' );

#TODO

#
# 8-$result->getResponse
#

eval { $result->getResponse(); };

ok( $@, '$r->getResponse should fail' );

#
# 9-
#

###
### SUBS
###

sub minimalResult {
	my %engine = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig('engine');
	my $t      = new HTTP::OAI::DataProvider::Transformer(
		nativePrefix => $nativePrefix,
		locateXSL    => $engine{locateXSL},
	);

	return new HTTP::OAI::DataProvider::Engine::Result(
		transformer => $t,
		verb        => 'GetRecord',
	);
}
