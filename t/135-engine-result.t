#!perl 
#-T

use strict;
use warnings;
use Test::More tests => 12;
use HTTP::OAI;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Transformer;
use Scalar::Util qw(blessed);

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Engine::Result') || print "Bail out!
";
}

#
# test new
#

my $t;
{
	my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	my %t_config = (
		nativePrefix => $config->{nativePrefix},
		locateXSL    => $config->{locateXSL},
	);
	$t = new HTTP::OAI::DataProvider::Transformer(%t_config);
}

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

my %opts = (
	transformer => $t,
	verb        => 'GetRecord',
);

my $result = new HTTP::OAI::DataProvider::Engine::Result(%opts);
ok( blessed($result) eq 'HTTP::OAI::DataProvider::Engine::Result',
	'new works' );

#
# $result->requestURL
#

my $url = $result->requestURL();    #getter
ok( !$url, 'url doesn\'t exist' );

$url = $result->requestURL('http://some.uri.com') or die "Wrong!";    #setter
ok( $url eq 'http://some.uri.com', 'url exists now' );

$url = $result->requestURL();                                         #getter
ok( $url eq 'http://some.uri.com', 'url exists now' );


#
# $result->addError($code[, $message]);
# $result->isError()
#

ok ( !$result->isError, 'isError should return nothing' );

eval { $result->addError('nonsense'); };
ok( $@, 'should fail: ' . $@ );

$result->addError('badArgument');
ok( $result->addError('badArgument'), 'adds error and returns true' );

ok ( $result->isError, 'isError should return true' );

my @err=$result->isError();
ok ( $err[0]->code eq 'badArgument', 'isError contains right HTTP::OAI error' ); 
