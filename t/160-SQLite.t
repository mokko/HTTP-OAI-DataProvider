use strict;
use warnings;
use Test::More tests => 11;
use HTTP::OAI::DataProvider::Test;
use Scalar::Util qw(blessed);
use FindBin;
use File::Spec;
use Cwd qw(realpath);

BEGIN {
	use_ok('HTTP::OAI::DataProvider::Engine::SQLite') || print "Bail out!
";
}

my %config = loadWorkingTestConfig();

my $db = new HTTP::OAI::DataProvider::Engine::SQLite(
	#database location
	dbfile    => $config{dbfile},
	#transformer
	locateXSL    => $config{locateXSL},
	nativePrefix    => $config{nativePrefix},
	nativeURI    => $config{native_ns_uri},
);

ok (blessed $db eq 'HTTP::OAI::DataProvider::Engine::SQLite', 'SQLite returns object');

#
# test inherited stuff from Interface
#

#
#error
#
ok (!$db->error, 'if NO message defined, dont raise one');
ok (!$db->error, 'transitive: call it again and it is the same result');

ok ($db->error('test'), 'dont pass anything to error or raises error: '.$db->error);
ok ($db->error, 'transitive: call it again and it is the same result: '.$db->error);

#
# valFileExists
#

ok (!$db->valFileExists(), 'valFileExist fails without param: '.$db->error);
ok (!$db->valFileExists('/a/filePath/that/does/not/exist'), 'valFileExist fails: '.$db->error);
ok (!$db->valFileExists($FindBin::Bin), 'valFileExist fails for $FindBin::Bin: '.$db->error);
my $absolute=realpath (__FILE__);
#TODO:i should create a link and test that too
ok ($db->valFileExists($absolute), "valFileExist succeeds for $absolute: ".$db->error);

#digest_single
#my $xml_fn=File::Spec->catfile (testEnvironment('dir').'sampleData.mpx');
#print $xml_fn;

#
# granularity
#

#ok (1,'sd');
#ok ($db->granularity eq 'YYYY-MM-DDThh:mm:ssZ', 'granularity looks good');
