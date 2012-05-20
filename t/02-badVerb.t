use strict;
use warnings;
use Test::More tests => 1;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test qw/basicResponseTests response2dom/;

my $config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider($config);

eval { my $response = $provider->badVerb(); };
ok (1, 'Todo...');
#okIfBadVerb;
#basicResponseTests($response);                 #two tests
#TODO...