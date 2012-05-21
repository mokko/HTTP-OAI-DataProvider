package HTTP::OAI::DataProvider::Common;
# ABSTRACT: common FUNCTIONs for the dataProvider

use strict;
use warnings;
use Scalar::Util;
use Carp qw(carp croak);

use base 'Exporter';
use vars '@EXPORT_OK';

@EXPORT_OK = qw(
  valPackageName
  isScalar
);

sub argumentsLeft;

=func isScalar ($variable);

Dies if $variable is not scalar

=cut

sub isScalar {
	my $value = shift
	  or die "Need value!";
	carp argumentsLeft if @_;

	die "Value is not a scalar"
	  if ( !Scalar::Util::reftype \$value eq 'SCALAR' );

	#there must be a better way, but this works...
	#new perldoc suggests not to use UNIVERSAL::isa as a function, so I don't
}

=func valPackageName ($obj,'Package::Name');

Dies with error message if $obj is not blessed with Package::Name. You can specify
more than one package name. Continues if any of them machtes. You may think of 
package names as class types.

You pass more than one Package::Name. Test passes if $obj is one of them.

=cut

sub valPackageName {
	my $obj      = shift or die "Error: Need an object!";
	my @expected = @_    or die "Error: Need object type (package name)";
	
	#print '...xxx...:'.ref($obj)."\n";
	my $type = Scalar::Util::blessed($obj);
	if ($type) {
		my @match =
		  grep ( $type eq $_, @expected );
		if ( scalar @match == 0 ) {
			die
			  "Error: Wrong type! Expected one of @expected, but instead it's "
			  . $type;
		}
	}
}


sub argumentsLeft {
	return "Carp: More agruments than expected";	
}
