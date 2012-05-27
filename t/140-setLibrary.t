#shebang?
use strict;
use warnings;
use Test::More tests => 5;
use HTTP::OAI::DataProvider::Test;
use Scalar::Util qw(blessed);
use HTTP::OAI;

#
# use
#
BEGIN {
	use_ok('HTTP::OAI::DataProvider::SetLibrary') || print "Bail out!
";
}

#
# new
#
my $library = new HTTP::OAI::DataProvider::SetLibrary();
ok( blessed($library) eq 'HTTP::OAI::DataProvider::SetLibrary',
	'new creates appropriate object' );

#
# addSet
#
eval { $library->addSet('bla') or die "Cant add!"; };
ok( $@, 'addSet should fail: ' . $@ );

my $s = new HTTP::OAI::Set();
$s->setSpec('a setSpec');
$s->setName('a name');
$s->setDescription('a description');

eval { $library->addSet($s) or die "Cant add!"; };

ok( !$@, 'addSet should have success' );

#
# expand
#

my $listSet= $library->expand ('a setSpec') or die "Can expand";
my $set=$listSet->set or die "Cant get set";
ok ($set->setSpec eq 'a setSpec','expand seems to work');

# 
# untested (todo): addListSet, show
#

