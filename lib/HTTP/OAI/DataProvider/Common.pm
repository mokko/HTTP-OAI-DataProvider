package HTTP::OAI::DataProvider::Common;
# ABSTRACT: common FUNCTIONs for the dataProvider

use strict;
use warnings;
use Scalar::Util;
use Carp qw(carp croak);
use Cwd qw(realpath);
use File::Spec;

use base 'Exporter';
our @EXPORT_OK;
our $modDir = _modDir();

@EXPORT_OK = qw(
  isScalar
  modDir
  valPackageName
);

sub argumentsLeft;

=func carp argumentsLeft if @_;

argumentsLeft stores just an error message in an attempt to unify the message
printed if the same error occurs.

=cut

sub argumentsLeft {
	return "Carp: More arguments than expected";
}

=func $modDir=modDir();

returns the directory of the module, e.g.
/usr/lib/perl5/site_perl/5.10/HTTP/OAI/DataProvider

=cut

sub modDir {
	return $modDir;
}

sub _modDir {
	my $_modDir = __FILE__;
	$_modDir =~ s,\.pm$,,;
	$_modDir = realpath( File::Spec->catfile( $_modDir, '..' ) );

	if ( !-d $_modDir ) {
		carp "modDir does not exist! ($_modDir)";
	}
	$modDir = $_modDir;
}

=func isScalar ($variable);

Dies if $variable is not scalar

=cut

sub isScalar {
	my $value = shift
	  or croak "Need value!";
	carp argumentsLeft if @_;

	croak "Value is not a scalar"
	  if ( !Scalar::Util::reftype \$value eq 'SCALAR' );

	#there must be a better way, but this works...
	#new perldoc suggests not to use UNIVERSAL::isa as a function, so I don't
}

=func valPackageName ($obj,'Package::Name');

Croak with error message if $obj is not blessed with Package::Name. You can specify
more than one package name. Continues if any of them machtes. You may think of 
package names as class types.

You pass more than one Package::Name. Test passes if $obj is one of them.

=cut

sub valPackageName {
	my $obj      = shift or croak "Error: Need an object!";
	my @expected = @_    or croak "Error: Need object type (package name)";

	#print '...xxx...:'.ref($obj)."\n";
	my $type = Scalar::Util::blessed($obj);
	if ($type) {
		my @match =
		  grep ( $type eq $_, @expected );
		if ( scalar @match == 0 ) {
			croak "Error: Wrong type! Expected one of @expected, "
			  . "but instead it's $type";
		}
	}
}