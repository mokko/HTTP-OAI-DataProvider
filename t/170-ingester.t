use strict;
use warnings;
use Test::More tests => 3;
use Scalar::Util qw(blessed);

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Ingester') || print "Bail out!
";
}

eval { my $mouth = new HTTP::OAI::DataProvider::Ingester(); };

ok( $@, 'new should fail' );

my $opts = { test => 'test', };

my $mouth = new HTTP::OAI::DataProvider::Ingester(
	engine     => 'HTTP::OAI::DataProvider::SQLite',
	engineOpts => $opts
);

ok (blessed $mouth eq 'HTTP::OAI::DataProvider::Ingester', 'ingester initialized');