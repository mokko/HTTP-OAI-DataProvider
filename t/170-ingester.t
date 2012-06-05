use strict;
use warnings;
use Test::More tests => 4;
use Scalar::Util qw(blessed);
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Common qw(Debug Warning);
use lib testEnvironment('dir'); #to load MPX from testEnviron
use MPX; 

my %engine = loadWorkingTestConfig('engine');
my %nativeFormat=loadWorkingTestConfig('nativeFormat');
my $nativePrefix=(keys %nativeFormat)[0];
die "No config! " if ( !%engine );

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


my $ingester = new HTTP::OAI::DataProvider::Ingester(
	engine       => $engine{engine},
	nativePrefix => $nativePrefix,
	nativeURI    => $nativeFormat{$nativePrefix},
	dbfile    => $engine{dbfile},
);

ok( blessed $ingester eq 'HTTP::OAI::DataProvider::Ingester',
	'ingester initialized' );


my $small=File::Spec->catfile (testEnvironment('dir'),'sampleData-small.mpx');
my $ret=$ingester->digest( source => $small, mapping => \&MPX::extractRecords ) or die "Can't digest";
ok ( $ret, "import of $small seems to work (returns true)");

