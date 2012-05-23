use strict;
use warnings;
use HTTP::OAI::DataProvider::Common qw(isScalar valPackageName);
use Test::More tests => 12;

#use Data::Dumper qw(Dumper); #only for debugging tests

{
	my $bla  = 'somestring';

	eval { isScalar($bla); };
	ok( !$@, 'isScalar should NOT die (scalar)' );

	eval { isScalar( 'band' => 'on the run' ); };
	ok( !$@, 'isScalar should die (hash)' );

	my $test = \$bla;
	eval { isScalar($test); };
	ok( !$@, 'isScalar should die (scalarref)' );
}

#
#
#diag "testing valPackageName";
eval { valPackageName(); };
ok( $@, 'valPackageName should die without params' );

my $obj = {};
bless( $obj, 'Test::Object' );
eval { valPackageName($obj); };
ok( $@, 'should die too few params' );

eval { valPackageName( $obj, 'Test::Object' ); };
ok( !$@, 'pass with good params' );

eval { valPackageName( $obj, 'bla::bla', 'Test::Object' ); };
ok( !$@, 'pass with multiple package names' );

eval { valPackageName( $obj, 'Test::Object', 'bla::bla' ); };
ok( !$@, 'with multiple package names indifferent of order' );

eval { valPackageName( $obj, 'Test::Object', 'bla::bla', 'Beatles' ); };
ok( !$@, 'with multiple package names indifferent of order' );

$obj = 'xssscalar';
eval { valPackageName( $obj, 'Test::Object', 'bla::bla', 'Beatles' ); };
ok( !$@, 'fail with bad obj (string)' );

$obj = { 'xsshash' => 'meter maid' };
eval { valPackageName( $obj, 'Test::Object', 'bla::bla', 'Beatles' ); };
ok( !$@, 'fail with bad obj (hashref)' );

{
	my $string = 'bla';
	$obj = \$string;

	eval { valPackageName( $obj, 'Test::Object', 'bla::bla', 'Beatles' ); };
	ok( !$@, 'fail with bad obj (scalarref)' );
}
