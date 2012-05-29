#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use File::Spec;
use Dancer;
#use Dancer::Logger;
#so you don't have to type 'perl -Ilib bin/eg-app.pl'
use lib File::Spec->catfile($FindBin::Bin,'..','lib');
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;

=head1 INTRODCUTION

This is an example of how to use HTTP::OAI::DataProvider in a webapp. I use 
Dancer because I like it. I tested the provider only with Dancer, but I assume 
that you should also work with in CGI or the webframework of your choice.

=head1 INSTRUCTIONS

1) start the example app by typing from the shell

bin/eg-app.pl

2) Go to your browser and visit http:://localhost:3000/?verb=Identify

3) log info should be t/dancer.log

=cut

#use Dancer's debug and warning irrespective of the test configuration
my $logdir=File::Spec->catfile($FindBin::Bin,'..','t','log');
die "Logdir doesn't exist!" if (!-e $logdir); 

my %config   = loadWorkingTestConfig();
$config{debug}=\&debug;
$config{warning}=\&warning;

set logger => 'file';
setting log_path => $logdir;
setting public => File::Spec->catfile($FindBin::Bin,'..','t','public');

my $provider = new HTTP::OAI::DataProvider(%config) or die "Cant create provider!";


any [ 'get', 'post' ] => '/' => sub {
	#without this content type xslt will not be applied by your browser
	content_type 'text/xml'; 
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
