#just test new with options, dont test any of the functionality
use HTTP::OAI::DataProvider;
use FindBin;
use Test::More;

#only for debugging tests
#use Data::Dumper qw(Dumper);

#load a working standard test config which should have ONLY required values
my $config_file = "$FindBin::Bin/test_config";
die "Error: no config file! " if !-f $config_file;
my $config = do $config_file or die "Error: Options not loaded";

plan tests => 1 + keys( %{$config} ) + 4;

# 1. Does it work? Return value right?
#
my $provider = HTTP::OAI::DataProvider->new($options);

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
	my $config = do $config_file or die "Error: Options not loaded";
	undef $options->{$value};
	eval { my $provider = HTTP::OAI::DataProvider->new($options) };
	ok( $@, "should fail without $value" );
}

#
# 2.2 test options: should succeed without options
#
my @options = qw(debug xslt requestURL warning);

foreach my $value (@options) {
	my $config = do $config_file or die "Error: Options not loaded";
	undef $options->{$value};
	my $provider;
	eval { $provider = HTTP::OAI::DataProvider->new($options) };

	ok(
		ref $provider eq 'HTTP::OAI::DataProvider',
		"should succeed without $value"
	);
}

#
#TODO test validations of parameters/options
#for that to happen with need validation first. Where should validation happen? 
#Before we start to validate we should correct the db-layer abstraction
