#!/usr/bin/perl
#PODNAME: webapp
#ABSTRACT: demo of web frontend to HTTP::OAI::DataProvider
use strict;
use warnings;
use FindBin;
use File::Spec;
use Dancer;
#so you don't have to type 'perl -Ilib bin/webapp.pl'
use lib File::Spec->catfile($FindBin::Bin,'..','lib');
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;

=head1 INTRODCUTION

This is an example of how to use HTTP::OAI::DataProvider in a webapp. I use 
Dancer because I like it. I tested the provider only with Dancer, but I assume 
that it should also work with in CGI or the PSGI webframework of your choice.

=head1 INSTRUCTIONS

1) start this app in the shell: bin/webapp.pl

2) In your webbrowser point to http:://localhost:3000/?verb=Identify

3) check log at t/environment/development.log

=cut

my $rootdir=File::Spec->catfile($FindBin::Bin,'..','t','environment');
my $logdir=File::Spec->catfile($rootdir,'log');
die "Logdir doesn't exist!" if (!-e $logdir); 

my %config   = loadWorkingTestConfig();
#use Dancer's debug and warning irrespective of the test configuration
$config{debug}=\&debug;
$config{warning}=\&warning;

set logger => 'file';
setting log_path => $logdir;
setting public => File::Spec->catfile($rootdir,'public'); #for oai2.xsl

my $provider = new HTTP::OAI::DataProvider(%config) or die "Cant create provider!";

any [ 'get', 'post' ] => '/' => sub {
	content_type 'text/xml'; #to make browser use oai2.xsl
	my ( $verb, %params ) = prepareParams();
	return $provider->$verb(%params);
};

sub prepareParams {
	my %params;
	my $verb = param('verb') or return;
	foreach my $key ( keys %{ params() } ) {
		if ( $key ne 'verb' ) {
			$params{$key} = param $key;
		}
	}
	return $verb, %params;
}

dance;

=head1 SEE ALSO

L<Dancer>, L<HTTP::OAI>