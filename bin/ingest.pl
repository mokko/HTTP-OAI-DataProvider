#!/usr/bin/perl
#PODNAME:
#ABSTRACT: demo the data provider's ingest feature

use strict;
use warnings;
use Getopt::Long;

use FindBin;
use File::Spec;
use lib File::Spec->catfile( $FindBin::Bin, '..', 'lib' );

use HTTP::OAI::DataProvider::SQLite;
use HTTP::OAI::DataProvider::Common qw(say);
use Pod::Usage;

sub verbose;
sub error;

=head1 DESCRIPTION

Ingest an xml file containing example data into the data providers database 
using DataProvider::SQLite and an example mapping for the MPX format using
the mapping in Format::MPX.

=head1 USAGE

ingest.pl file.xml

=head1 OPTIONS
--config path/to/config.pl [optional]
	load configuration other than $moduleDirectory/t/test_config
--help [optional]
	this help text
--verbose [optional]
	be more verbose

=cut

#
# USER INPUT
#

my %opts; #from cli
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

my %config = loadConfig(); #from file

#
# MAIN
#

my $db= new HTTP::OAI::DataProvider::SQLite (%opts);
#do i really need the chunkCache just ingest some data? hardly.
#but if I make it optional, it could go missing when I need it, so put tests back in
#for when I do need it.


#
# SUBs
#

=head2 ...INTERNAL...

If all goes well, you don't need to look at the internals.

=cut

sub loadConfig {
	my $configFile;
	if ( $opts{c}) {
		$configFile = $opts{c};
	}
	else {
		$configFile = HTTP::OAI::DataProvider::Common::testEnvironment('config');
	}

	if ( !-f $configFile ) {
		error "Error: Can\'t find config file ($configFile)\n";
	}

	my %config = do $configFile or die "Error: Configuration not loaded";

	#die "Error: Not a hashref" if ref $config ne 'HASH';
	verbose (" Config file $configFile loaded");
	return %config;
}

=head 2 ...Messages...

=func verbose "bla";

Prints message if $opt{v} defined.

=cut

sub verbose {
	my $msg = shift or return;
	say '*' . $msg if ( $opts{v} );
}

=func error "message";

Prints an error message and exits.

=cut

sub error {
	my $msg = shift;    #optional
	say "Error: $msg";
	exit 0;
}
