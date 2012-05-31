use strict;
use warnings;
use Test::More tests => 3;
use Scalar::Util qw(blessed);
use HTTP::OAI::DataProvider::Test;

=head1 CONCEPT

This test simulates (to be) HTTP::OAI::DataProvider
a) use Ingester
b) make a new Ingester requiring Engine::SQL
c) import some data

=cut

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Ingester') || print "Bail out!
";
}

###
### new
###

{
	eval { my $ingester = new HTTP::OAI::DataProvider::Ingester(); };
	ok( $@, 'new should fail' );
}

my %config = loadWorkingTestConfig();
die "No config! " if ( !%config );

my $ingester = new HTTP::OAI::DataProvider::Ingester(
	engine       => 'HTTP::OAI::DataProvider::Engine::SQLite',
	nativePrefix => $config{nativePrefix},
	nativeURI    => $config{native_ns_uri},
	dbfile    => $config{dbfile},
);

ok( blessed $ingester eq 'HTTP::OAI::DataProvider::Ingester',
	'ingester initialized' );
