#just test new with options, dont test any of the functionality
use strict;
use warnings;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use Test::More;

#use Data::Dumper qw(Dumper); #only for debugging tests


#load a working standard test config which should have ONLY required values
my $config=HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

plan tests => 1 + keys( %{$config} ) + 4;

# 1. Does it work? Return value right?
#
my $provider = HTTP::OAI::DataProvider->new($config);

ok(
	ref $provider eq 'HTTP::OAI::DataProvider',
	'HTTP::OAI::DataProvider object initiated'
);

#
# 2. Input (options/params exist)
# 2.1 parameters (aka 'required options')

my @required = qw(
  adminEmail
  baseURL
  chunkCacheMaxSize
  chunkSize
  dbfile
  deletedRecord
  GlobalFormats
  locateXSL
  nativePrefix
  native_ns_uri
  repositoryName
);

foreach my $value (@required) {
	my $config=HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	undef $config->{$value};
	eval { my $provider = HTTP::OAI::DataProvider->new($config) };
	ok( $@, "should fail without $value" );
}

#
# 2.2 test options: should succeed without options
#
my @options = qw(debug xslt requestURL warning);

foreach my $value (@options) {
	my $config=HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
	undef $config->{$value};
	my $provider;
	eval { $provider = HTTP::OAI::DataProvider->new($config) };

	ok(
		ref $provider eq 'HTTP::OAI::DataProvider',
		"should succeed without $value"
	);
}

#
#TODO test validations of parameters/options
#for that to happen with need validation first. Where should validation happen? 
#Before we start to validate we should correct the db-layer abstraction
