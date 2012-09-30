#!/usr/bin/perl
#PODNAME: dp.pl
#ABSTRACT: command line interface to HTTP::OAI::DataProvider

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use File::Spec;

#should make allow this script to the find the packages before install, like
#perl -Ilib bin/dp.pl
use lib File::Spec->catfile( $FindBin::Bin, '..', 'lib' );
use HTTP::OAI;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Common;
use Pod::Usage;

our %opts;
sub verbose;

=head1 DESCRIPTION

A simple command line interface to HTTP::OAI::DataProvider to execute verbs 
for testing and debugging. 

Note: Neither HTTP::OAI::DataProvider nor this script provide a web front
end. See bin/eg-app.pl for an example implementation of a webapp.

=head1 SYNOPSIS

	#OAI verbs and paramters
	dp --verb Identify
	dp --verb GetRecord --identifier 12342 --metadataPrefix oai_dc

	#other arguments
	--verbose #more info from dp.pl [optional]
	--config '/path/to/config.pl' [optional]
	
	If --config is not specified, this script loads t/test_config. 

=head1 CONFIG FILE FORMAT

Current format is pure perl, see t/test_config for example.

=head1 KNOWN BUGS
After being install using 'make install' this script won't find the config in t 
anymore. Use --config parameter instead.

=head1 INTERNAL INTERFACE

Normally, you should never need any of the following functions.

=cut

my %params   = getOpt();               #from command line
my %config   = loadConfig();           #from disk
my $response = executeVerb(%params);
verbose "OAI response";
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
    my $configFile;
    if ( $opts{c} ) {
        $configFile = $opts{c};
    }
    else {
        $configFile =
          HTTP::OAI::DataProvider::Common::testEnvironment('config');
    }

    if ( !-f $configFile ) {
        print "Error: Cant find config file ($configFile)\n";
        exit 1;
    }

    my %config = do $configFile or die "Error: Configuration not loaded";

    #die "Error: Not a hashref" if ref $config ne 'HASH';
    verbose(" Config file $configFile loaded");
    return %config;
}

=func my %params=getOpt();
=cut

sub getOpt {
    my %params;
    GetOptions(
        'config=s'          => \$opts{c},
        'help'              => \$opts{h},
        'identifier=s'      => \$params{identifier},
        'from=s'            => \$params{from},
        'metadataPrefix=s'  => \$params{metadataPrefix},
        'resumptionToken=s' => \$params{resumptionToken},
        'set=s'             => \$params{set},
        'until=s'           => \$params{'until'},
        'verb=s'            => \$params{verb},
        'verbose'           => \$opts{v},
    );
    pod2usage(1) if ( $opts{h} );

    #cleanup the hash
    verbose "Input params";
    foreach my $key ( keys %params ) {
        if ( !$params{$key} ) {
            delete $params{$key};
        }
        else {
            verbose " $key: " . $params{$key};
        }
    }

    validateRequest(%params);
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
    verbose " Input params validate";
}

=func my $response=executeVerb (%params);
=cut

sub executeVerb {
    my %params = @_ or die "Need params!";
    my $verb = $params{verb};
    delete $params{verb};
    verbose "About to execute $verb";

    #new might die on error
    my $provider = new HTTP::OAI::DataProvider(%config)
      or die "Cant create new object";

    return $provider->$verb(%params) or die "Cant execute verb!";
}

=func verbose "bla";
	prints message if $opt{v} defined
=cut

sub verbose {
    my $msg = shift or return;
    print '*' . $msg . "\n" if ( $opts{v} );
}
