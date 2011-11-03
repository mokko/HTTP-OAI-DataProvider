#!perl

use Test::More tests => 2;
use HTTP::OAI::DataProvider;
use FindBin;
#use Data::Dumper qw(Dumper);

#LOAD CONFIG, doesn't work with TAINT mode
my $config = do "$FindBin::Bin/config.pl";
die "options not loaded" if ( !$options );

my $provider = HTTP::OAI::DataProvider->new($options);
my $response = $provider->Identify();    #response should be a xml string

ok( $response, 'response exists' );
ok( $response =~ /<OAI-PMH/, 'response looks ok' );

#diag( "Testing new HTTP::OAI::DataProvider $HTTP::OAI::DataProvider::VERSION, Perl $], $^X" );
