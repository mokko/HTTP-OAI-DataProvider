# this is not a proper test, instead it will unpack sample data and
# try to import it into the database
# the first time it runs it will take up quite a bit of time.

use strict;
use warnings;
use Archive::Extract;
use HTTP::OAI::DataProvider::Test;
use Test::More tests => 2;
use HTTP::OAI::DataProvider::Ingester;
use File::Spec;
use lib testEnvironment('dir');    #to load MPX from testEnviron
use MPX;

my $zipfile = testEnvironment( 'dir', 'sampleData.zip' );
my $target  = testEnvironment( 'dir', 'sampleData-big.mpx' );

##
##
##

if ( -f $target ) {
	pass "zip appears to be already unzipped";
}
else {
	if ( !-f $zipfile ) {
		fail "zipfile $zipfile doesn't exist";
	}

	my $ae = Archive::Extract->new( archive => $zipfile );

	$ae->extract(
		to => testEnvironment 'dir
		  '
	) or fail "Cant unzip" . $ae->error;
	ok( !$ae->error, 'extract ok' );
}

###
###
###

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

	print 'Digesting may last quite a while. You may want to interrupt it '
	  . 'with CTRL+C and start tests again. During the second run environment '
	  . 'should be initialized. You may have to adjust the date for earliestDate '
	  . "in this case\n";

	my $ret =
	  $ingester->digest( source => $target, mapping => \&MPX::extractRecords )
	  or die "Can'
		  t digest ";
	ok( $ret, " import of $target seems to have worked( returned true ) " );

}
