#just test new with options, dont test any of the functionality
use strict;
use warnings;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use Test::More tests => 15;

#use Data::Dumper qw(Dumper); #only for debugging tests

#load a working standard test config which should have ONLY required values
my %config  = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my @options = qw(debug requestURL warning xslt);

# 1. Does it work? Return value right?
#
my $provider = HTTP::OAI::DataProvider->new(%config);

ok(
	ref $provider eq 'HTTP::OAI::DataProvider',
	'HTTP::OAI::DataProvider object initiated'
);

#
# 2. Input (options/params exist)
# 2.1 parameters (aka 'required options')

my @required = qw(
  engine
  globalFormats
  identify
  setLibrary
);

foreach my $value (@required) {
	my $config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	undef $config{$value};
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail without $value" );
}

#
# 2.2 test options: should succeed without options
#

foreach my $value (@options) {

	#print "Try without $value\n";
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	delete $config{$value};
	my $provider;
	eval { $provider = HTTP::OAI::DataProvider->new(%config); };

	my $msg = "succeed without $value ";
	$msg .= $@ if ($@);
	ok( ref $provider eq 'HTTP::OAI::DataProvider', $msg );
}

#
# fail with wrong globalFormats
#

{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	delete $config{globalFormats}{mpx}{ns_uri};
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail without ns_uri" );

}

{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	delete $config{globalFormats}{mpx}{ns_schema};
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail without ns_schema" );

}

{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	$config{globalFormats}{mpx}{ns_schema} = 'this is Not a url';
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail without ns_schema" );

}

{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	$config{globalFormats}{mpx}{ns_uri} = 'this is Not a url';
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail without ns_uri" );

}

#
# fail with requestURL that is no uri
#

{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	$config{requestURL} = 'this is Not a url';
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail when requestURL has no uri" );

}

#
# fail with baseURL that is no uri
#

{
	my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	$config{identify}{baseURL} = 'this is Not a url';
	eval { my $provider = HTTP::OAI::DataProvider->new(%config) };
	ok( $@, "fail when baseURL has no uri" );

}
