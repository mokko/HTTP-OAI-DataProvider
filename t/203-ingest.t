use strict;
use warnings;
use Test::More tests=>2;

BEGIN {
    use_ok( 'HTTP::OAI::DataProvider::SQLite' ) || print "Bail out!
";
}

my %opts;
my $db=new HTTP::OAI::DataProvider::SQLite(%opts);


#test if I can import data from XML to sqlite db...
ok ($db, 'new creates something');
#todo