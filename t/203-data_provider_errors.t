use strict;
use warnings;
use Test::More;
use HTTP::OAI;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
plan tests => 14;

my %config = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig;
my $provider=HTTP::OAI::DataProvider->new(%config);

#use Data::Dumper 'Dumper';

ok (!$provider->error, 'no error yet');
my $response=$provider->OAIerrors;
ok (ref $response eq 'HTTP::OAI::Response','response object exists');
ok ($response->error, 'response is not an error'); #not sure why so tricky...
ok ($response->errors == 0, 'response is not an error'); #not sure why so tricky...

$response=$provider->addError(code=>'badArgument');
ok (ref $response eq 'HTTP::OAI::Response','response object exists');
ok ($response->errors,'response is error');
my $xml=$provider->asString($response);
ok ($xml=~/badArgument/,'badArgument found') ;

$response=$provider->addError(code=>'badGranularity');
ok (ref $response eq 'HTTP::OAI::Response','response object exists');
ok ($response->errors,'response is error');
$xml=$provider->asString($response);
ok ($xml=~/badArgument/ && $xml=~/badGranularity/,'both errors found') ;
ok ($provider->error, 'error has occured');

$response=$provider->OAIerrors;
ok (ref $response eq 'HTTP::OAI::Response','response object exists');
ok ($response->error, 'response is an error');
ok ($response->errors > 0, 'response is an error'); #not sure why so tricky...
#print $xml;



