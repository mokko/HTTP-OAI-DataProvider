#!perl

use strict;    #test the test (this is so meta...)
use warnings;
use Test::More tests => 1;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI;

#use Data::Dumper qw(Dumper); #only for debugging tests

my $id=new HTTP::OAI::Identify(
	adminEmail     => 'billg@microsoft.com',
	baseURL        => 'http://www.myarchives.org/oai',
	repositoryName => 'www.myarchives.org'
);

my $response=$id->toDOM->toString;
print "$response\n";
okIdentify($response);
