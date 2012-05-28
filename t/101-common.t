use strict;
use warnings;
use FindBin;
use HTTP::OAI::DataProvider::Common
  qw(isScalar valPackageName modDir Warning Debug);
use Test::More tests => 16;

#use Data::Dumper qw(Dumper); #only for debugging tests

{
	my $bla = 'somestring';

	eval { isScalar($bla); };
	ok( !$@, 'isScalar should NOT die (scalar)' );

	eval { isScalar( 'band' => 'on the run' ); };
	ok( !$@, 'isScalar should die (hash)' );

	my $test = \$bla;
	eval { isScalar($test); };
	ok( !$@, 'isScalar should die (scalarref)' );
}

{

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
}

	#don't know how to test modir
	#print "bin:$FindBin::Bin\n";
	#print "modDir: ".modDir()."\n";

eval { Debug "bla" };
ok( $@, 'expect Debug to croak' );

Debug( sub { my $msg = shift; print ">>>>>>>>>>>>>>>>>>$msg\n" if $msg } );
eval { Debug "bla" };
ok( !$@, 'expect Debug to succeed' );

eval { Warning "bla" };
ok( $@, 'expect Warning to croak ' );

Warning( sub { my $msg = shift; warn ">>>>>>>>>>>>>>>>>>$msg" if $msg } );
eval { Warning "wla" };
ok( !$@, 'expect Warning to succeed' );
