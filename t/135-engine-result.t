#!perl 
#-T

use strict;
use warnings;
use Test::More tests => 16;
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

my %engine = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig('engine');
my %nativeFormat =
  HTTP::OAI::DataProvider::Test::loadWorkingTestConfig('nativeFormat');
my $nativePrefix = ( keys(%nativeFormat) )[0];

my $t;    #used in subsequent tests!
{
	$t = new HTTP::OAI::DataProvider::Transformer(
		nativePrefix => $nativePrefix,
		locateXSL    => $engine{locateXSL},
	);
}

#
# 1-test new
#

{
	my %opts;
	$opts{transformer} = $t;
	eval { my $result = new HTTP::OAI::DataProvider::Engine::Result(%opts); };
	ok( $@, 'should fail: ' . $@ );
}

{
	my %opts;
	$opts{verb} = 'GetRecord';
	eval { my $result = new HTTP::OAI::DataProvider::Engine::Result(%opts); };
	ok( $@, 'should fail: ' . $@ );
}

my $result = minimalResult();
{

	ok( blessed($result) eq 'HTTP::OAI::DataProvider::Engine::Result',
		'new works' );
}

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
ok( $@, 'should fail: ' . $@ );

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

#TODO see if it changes

#
# 6-$result->chunkSize
#
{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	die "Need chunkSize" if ( !$config{chunkSize} );

	my %opts = (
		transformer => $t,
		verb        => 'GetRecord',
		chunkSize   => $config{chunkSize},
	);
	$result = new HTTP::OAI::DataProvider::Engine::Result(%opts);
	new HTTP::OAI::DataProvider::Engine::Result(%opts);
	ok( $result->chunkSize == $config{chunkSize}, 'chunkSize seems right' );
}

#
# 7-$result->getType();
#

ok( $result->getType(), '$r->getType is weird' );

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
	my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	my %t_config = (
		nativePrefix => $config{nativePrefix},
		locateXSL    => $config{locateXSL},
	);
	my $t = new HTTP::OAI::DataProvider::Transformer(%t_config);

	my %opts = (
		transformer => $t,
		verb        => 'GetRecord',
	);
	return new HTTP::OAI::DataProvider::Engine::Result(%opts);
}
