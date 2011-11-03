#!perl

use Test::More tests => 1;
use HTTP::OAI::DataProvider;
use FindBin;
#use Data::Dumper qw(Dumper);

#LOAD CONFIG, doesn't work with TAINT mode
my $config = do "$FindBin::Bin/config.pl";
die "options not loaded" if (!$options);

my $provider = HTTP::OAI::DataProvider->new($options);
ok( $provider, 'HTTP::OAI::DataProvider object initiated' );

#diag( "Testing new HTTP::OAI::DataProvider $HTTP::OAI::DataProvider::VERSION, Perl $], $^X" );
