#!/usr/bin/perl
#PODNAME: ingest.pl
# ABSTRACT: demo the data provider's ingest feature

use strict;
use warnings;
use Getopt::Long;
use Carp 'confess';

use FindBin;
use File::Spec;
use XML::LibXML;
use Pod::Usage;
use lib File::Spec->catfile( $FindBin::Bin, '..', 'lib' );
use HTTP::OAI::DataProvider::Ingester;
use HTTP::OAI::DataProvider::Mapping::MPX;
use HTTP::OAI::DataProvider::Common qw(
  Debug
  say
  testEnvironment
  Warning
);

sub verbose;
sub error;


#
# USER INPUT
#

my %opts = userInput();    #from cli

#
# MAIN
#
my %config = loadConfig();    #from file
$config{engine}    = 'HTTP::OAI::DataProvider::Engine::SQLite';
$config{nativeURI} = $config{native_ns_uri};
my $ingester = new HTTP::OAI::DataProvider::Ingester(%config)
  or die "Cant make new Ingester";
verbose " ingester loaded successfully with config from '$opts{c}'";
verbose " starting to ingest file '$ARGV[0]' using mapping from  "
  . " 't/environment/MPX.pm' (this may take a while with big xm files)"
  ;
$ingester->digest( source => $ARGV[0], mapping => \&MPX::extractRecords )
  or confess "Can't digest";
verbose " ingest complete";

###
### SUBs
###


sub loadConfig {
	my $configFile;
	if ( $opts{c} ) {
		$configFile = $opts{c};
	}
	else {
		$configFile =
		  HTTP::OAI::DataProvider::Common::testEnvironment('config');
		$opts{c} = $configFile;
	}

	if ( !-f $configFile ) {
		error "Error: Can\'t find config file ($configFile)\n";
	}

	my %config = do $configFile or die "Error: Configuration not loaded";

	#die "Error: Not a hashref" if ref $config ne 'HASH';
	verbose(" Config file $configFile loaded");
	return %config;
}


sub verbose {
	my $msg = shift or return;
	say '*' . $msg if ( $opts{v} );
}


sub error {
	my $msg = shift;    #optional
	say "Error: $msg";
	exit 0;
}


sub userInput {

	GetOptions(
		'config=s' => \$opts{c},
		'help'     => \$opts{h},
		'verbose'  => \$opts{v},
	);
	pod2usage(1) if ( $opts{h} );

	if ( !$ARGV[0] ) {
		error "No input file!";
	}

	if ( !-e $ARGV[0] ) {
		error "Input file not found ($ARGV[0])!";
	}
	return %opts;
}


__END__
=pod

=head1 NAME

ingest.pl - demo the data provider's ingest feature

=head1 VERSION

version 0.007

=head1 DESCRIPTION

Ingest an xml file containing example data into the data providers database 
using DataProvider::SQLite and an example mapping for the MPX format using
the mapping in Format::MPX.

=head1 FUNCTIONS

=head2 verbose "bla";

Prints message if $opt{v} defined.

=head2 error "message";

Prints an error message and exits.

=head2 %opts=userInput ();

Parse long options in hash %opts;

=head1 USAGE

ingest.pl file.xml

=head1 OPTIONS
--config path/to/config.pl [optional]
	load configuration other than $moduleDirectory/t/test_config
--help [optional]
	this help text
--verbose [optional]
	be more verbose

=head2 ...INTERNAL...

If all goes well, you don't need ever to look at the internals.

=head2 ...Messages...

=head2 ...Utility...

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

