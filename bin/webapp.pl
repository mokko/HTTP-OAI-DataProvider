#!/usr/bin/perl
#PODNAME: webapp.pl
# ABSTRACT: demo of web frontend to HTTP::OAI::DataProvider
use strict;
use warnings;
use FindBin;
use Dancer;
use Path::Class;

use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;

my $rootdir = dir( dir($FindBin::Bin)->parent, 't', 'environment' );
my %config  = loadWorkingTestConfig();

#use Dancer's debug and warning irrespective of the test configuration
$config{debug}   = \&Dancer::debug;
$config{warning} = \&Dancer::warning;

set logger     => 'console';
setting public => dir( $rootdir, 'public' );    #for oai2.xsl

my $provider = new HTTP::OAI::DataProvider(%config)
  or die "Cant create provider!";

any [ 'get', 'post' ] => '/' => sub {
	  content_type 'text/xml';                  #to make browser use oai2.xsl
	  my $response=$provider->verb( %{params()} );
	  return $provider->asString($response);
  };

dance;

=head1 INTRODCUTION

A working demo of HTTP::OAI::DataProvider inside a webapp. I use the web 
framework Dancer because I like it. Use whatever you like.

1) start this app from the shell: perl -Ilib bin/webapp.pl
   (app expects config file at '../t/environment/config.pl')

2) In your webbrowser point to http:://localhost:3000/?verb=Identify

=head1 SEE ALSO

L<http://perldancer.org|Dancer>, L<HTTP::OAI>
