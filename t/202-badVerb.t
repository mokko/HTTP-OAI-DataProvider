use strict;
use warnings;
use Test::More tests => 1;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;# qw/okIfBadVerb/;

my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);
eval { my $response = $provider->baaadVerb(); };
ok ($@, 'bad verb should fail:'.$@);
#print "$@/n";

