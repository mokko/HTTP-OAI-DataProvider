#!/usr/bin/perl
#APPNAME:
#ABSTRACT:

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use HTTP::OAI;

#not strictly necessary, but may not be a bad idea to leave it here, right?
use lib File::Spec->catfile( $FindBin::Bin, '..', 'lib' );
use HTTP::OAI::DataProvider;

=head1 SYNOPSIS

A simple command line interface to HTTP::OAI::DataProvider to execute verbs 
for testing and debugging:

dp --verb Identify
dp --verb GetRecord --identifier 12342 --metadataPrefix oai_dc

Currently this script loads t/test_config on start up as a config. 

=head1 INTERNAL INTERFACE

Normally, you should never need any of the following functions.

=cut

my $config = loadConfig();    #from disk
my %params = getOpt();        #command line
validateRequest(%params);
my $response = executeVerb(%params);
print "$response\n";
exit;

#
# SUBS
#

=func $config=loadConfig();

Expects nothing, dies on error and returns hashref. Currently loads
the standard test config used by most tests.

TODO:
make it look for ~/.dprc file and read that alternatively. 
Should I also use a yaml file?

=cut

sub loadConfig {
	my $configFile =
	  File::Spec->catfile( 'Findbin::Bin', '..', 't', 'test_config' );

	if ( !-f $configFile ) {
		print "Error: Cant find test config at $configFile\n";
		exit 1;
	}

	my $config = do $configFile or die "Error: Configuration not loaded";

	#in lieu of proper validation
	die "Error: Not a hashref" if ref $config ne 'HASH';

	return $config;
}

=func my %params=getOpt();
=cut

sub getOpt {
	my %params;
	GetOptions(
		'identifier=s'      => \$params{identifier},
		'from=s'            => \$params{from},
		'metadataPrefix=s'  => \$params{metadataPrefix},
		'set=s'             => \$params{set},
		'until=s'           => \$params{'until'},
		'verb=s'            => \$params{verb},
		'resumptionToken=s' => \$params{resumptionToken},
	);

	#cleanup the hash
	grep ( !$params{$_} ? delete $params{$_} : 1, keys %params );
	return %params;
}

=func validateRequest
=cut

sub validateRequest {
	my %params = @_ or die "Need params!";
	if ( my @err = HTTP::OAI::Repository::validate_request_2_0(%params) ) {
		print "Input error: \n";
		foreach (@err) {
			print "\t" . $_->code . ' - ' . $_->message . "\n";
		}
		exit 1;
	}
}

=func my $response=executeVerb (%params);
=cut

sub executeVerb {
	my %params = @_ or die "Need params!";
	my $verb = $params{verb};
	delete $params{verb};
	#new might die on error
	my $provider = new HTTP::OAI::DataProvider($config);
	return $provider->$verb(%params);
}
