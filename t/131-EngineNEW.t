#!perl

use strict;
use warnings;
use Test::More tests => 14;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Common qw(hashRef2hash);
use Cwd qw(realpath);

=head1 CONCEPT

This test simulates HTTP::OAI::DataProvider
a) use Engine
b) make a new engine requiring Engine::SQL
c) query

=cut

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Engine') || print "Bail out!
";
}

###
### Just NEW
###

my %config = loadWorkingTestConfig('engine');
die "No config! " if ( !%config );

#	dbfile       => $config{dbfile},
#	engine       => 'HTTP::OAI::DataProvider::Engine::SQLite',
#	locateXSL    => $config{locateXSL},
#	nativePrefix => $config{nativePrefix},
#	nativeURI    => $config{native_ns_uri},
my $engine = new HTTP::OAI::DataProvider::Engine(%config);

###
### test inherited stuff from Interface
###

#
#error
#
ok( !$engine->error, 'if NO message defined, dont raise one' );
ok( !$engine->error, 'transitive: call it again and it is the same result' );

{
	if ( $engine->error ) {
		fail 'if ($engine->error)';    #there was an error
	}
	else {
		pass 'if ($engine->error)'     #there was no error yet
	}
}

ok( $engine->error('test'),
	'dont pass anything to error or raises error: ' . $engine->error );
ok( $engine->error,
	'transitive: call it again and it is the same result: ' . $engine->error );

#
# resetError
#

$engine->resetError;

{
	if ( $engine->error ) {
		fail 'if ($engine->error) after resetError';    #there was an error
	}
	else {
		pass 'if ($engine->error) after resetError'     #there was no error yet
	}
}

ok( !$engine->error, 'error message should be gone' );

#
# valFileExists
#

ok( !$engine->valFileExists(),
	'valFileExist fails without param: ' . $engine->error );
ok( !$engine->valFileExists('/a/filePath/that/does/not/exist'),
	'valFileExist fails: ' . $engine->error );
ok( !$engine->valFileExists($FindBin::Bin),
	'valFileExist fails for $FindBin::Bin: ' . $engine->error );

{
	$engine->resetError;
	my $absolute = realpath(__FILE__);

	#TODO:i should create a link and test that too
	ok(
		$engine->valFileExists($absolute),
		"valFileExist succeeds for $absolute"
	);
}

###
### Simple Identify stuff
###

#
# granularity
#

ok( $engine->granularity eq 'YYYY-MM-DDThh:mm:ssZ', 'granularity looks good' );

#
# earliestDate
#

#print $engine->earliestDate()."\n";

#if you import new data in the test database you may have to adjust that date...
ok( $engine->earliestDate() eq '2011-02-15T10:03:46Z',
	'earliestDate looks good' );

###
### Real Queries
###