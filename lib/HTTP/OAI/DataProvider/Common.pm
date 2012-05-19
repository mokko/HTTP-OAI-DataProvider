package HTTP::OAI::DataProvider::Common;
# ABSTRACT: common FUNCTIONs for the dataProvider

use strict;
use warnings;
use Scalar::Util;

use base 'Exporter';
use vars '@EXPORT_OK';

@EXPORT_OK = qw(
	valPackageName
);


=func valPackageName ($obj,'Package::Name');

Dies with error message if $obj is not blessed with Package::Name. You can specify
more than one package name. Continues if any of them machtes. You may think of 
package names as class types.

=cut

sub valPackageName {
	my $doc      = shift or die "Error: Need doc!";
	my @expected = @_    or die "Error: Need object type (package name)";

	my @match = grep ( Scalar::Util::blessed($doc) eq $_, @expected );

	if ( scalar @match == 0 ) {
		die "Error: Wrong type! Expected one of @expected, but instead it's "
		  . blessed($doc);
	}
}

