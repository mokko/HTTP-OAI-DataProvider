package HTTP::OAI::DataProvider::Test;

use strict;
use warnings;
use FindBin;

=func my $config=HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

	loadWorkingTestConfig returns a hashref with a working configuration.

=cut

sub loadWorkingTestConfig {

	my $config = do "$FindBin::Bin/test_config"
	  or die "Error: Configuration not loaded";

	#in lieu of proper validation
	die "Error: Not a hashref" if ref $config ne 'HASH';

	return $config ;
}

1;
