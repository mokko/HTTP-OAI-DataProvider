use strict;
use warnings;
use Test::More tests => 2;
use HTTP::OAI::DataProvider::Test;
use Scalar::Util qw(blessed);
use FindBin;
use File::Spec;

BEGIN {
	use_ok('HTTP::OAI::DataProvider::SQLite') || print "Bail out!
";
}

my %config = loadWorkingTestConfig();

my $db = new HTTP::OAI::DataProvider::SQLite(
	#database location
	dbfile    => $config{dbfile},
	#transformer
	locateXSL    => $config{locateXSL},
	nativePrefix    => $config{nativePrefix},
	nativeURI    => $config{native_ns_uri},
);

ok (blessed $db eq 'HTTP::OAI::DataProvider::SQLite', 'SQLite returns object');

#digest_single
my $xml_fn=File::Spec->filecat (testEnvironment('dir').'sampleData.mpx');
print $xml_fn;
