# this is not a proper test, instead it will unpack sample data and
# try to import it into the database
# the first time it runs it will take up quite a bit of time.

use strict;
use warnings;
use Test::More tests => 1;
use File::Spec;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI::DataProvider::Ingester;
use HTTP::OAI::DataProvider::Mapping::MPX;

###
### create a SQLite db from a mpx source file
###

my $target=testEnvironment('dir','sampleData-big.mpx');

if (! -f $target) {
	die "mpx source at '$target' does not exist";
}

my %engine       = loadWorkingTestConfig('engine');
my %nativeFormat = loadWorkingTestConfig('nativeFormat');
my $nativePrefix = ( keys %nativeFormat )[0];
die "No config! " if ( !%engine );

if ( -f $engine{dbfile} ) {
	pass "db exists, ingester seems to have run already";
}
else {

	my $ingester = new HTTP::OAI::DataProvider::Ingester(
		engine       => $engine{engine},
		nativePrefix => $nativePrefix,
		nativeURI    => $nativeFormat{$nativePrefix},
		dbfile       => $engine{dbfile},
	);

	#print 'Digesting may last quite a while. You may want to interrupt it '
	#  . 'with CTRL+C and start tests again. During the second run environment '
	#  . 'should be initialized. You may have to adjust the date for earliestDate '
	#  . "in this case\n";

	my $ret = $ingester->digest(
		source  => $target,
		mapping => \&HTTP::OAI::DataProvider::Mapping::MPX::extractRecords
	) or die "Can't digest!";
	ok( $ret, " import of $target seems to have worked( returned true ) " );

}
