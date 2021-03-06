package HTTP::OAI::DataProvider::Common;
{
  $HTTP::OAI::DataProvider::Common::VERSION = '0.009';
}
use strict;
use warnings;

# ABSTRACT: common FUNCTIONs for the dataProvider

use Scalar::Util;
use Carp qw(carp croak);
use Cwd qw(realpath);

use FindBin;
use Path::Class;

use base 'Exporter';
our @EXPORT_OK;
our $modDir = _modDir();
our $Debug;
our $Warning;

@EXPORT_OK = qw(
  Debug
  isScalar
  modDir
  say
  testEnvironment
  valPackageName
  Warning
);

sub argumentsLeft;


sub argumentsLeft {
	return "Carp: More arguments than expected";
}


sub modDir {
	return $modDir;
}

#load this once when the module is loaded
##sub _modDir {
#	my $_modDir = __FILE__;
#	$_modDir =~ s,\.pm$,,;
#	$_modDir = realpath( File::Spec->catfile( $_modDir, '..' ) );
#
#	if ( !-d $_modDir ) {
#		carp "modDir does not exist! ($_modDir)";
#	}
#	$modDir = $_modDir;
#}


sub _modDir {
	return file(__FILE__)->parent;
}


sub isScalar {
	my $value = shift
	  or croak "Need value!";

	croak "Carp: More arguments than expected" if (@_);
	croak "Value is not a scalar"
	  if ( Scalar::Util::reftype \$value ne 'SCALAR' );

	#there must be a better way, but this works...
	#new perldoc suggests not to use UNIVERSAL::isa as a function
}


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


sub Debug {
	my @orig = @_;
	my $arg  = shift;
	if ( $arg && defined &$arg ) {

		#print "SEEMS TO BE CODEREF $arg\n";
		$Debug = $arg;
	}
	else {

		#print "NOT a CODEREF $arg\n";
		&$Debug(@orig) if $Debug;

		#it is perfectly possible that Debug is not initialized, so don't croak
	}
}


sub Warning {
	my @orig = @_;
	my $arg  = shift;
	if ( $arg && defined &$arg ) {
		$Warning = $arg;
	}
	else {
		&$Warning(@orig) if $Warning;

	   #it is perfectly possible that Warning is not initialized, so don't croak
	}
}

sub say {
	print "@_\n";
}


sub testEnvironment {
	my $arg = shift;
	my $dir = file($FindBin::Bin);
	$dir = dir( $dir->parent, 't', 'environment' );

	if ( $arg eq 'config' ) {
		return file( $dir, 'config.pl' );
	}

	if (@_) {
		$dir = file( $dir, @_ );
	}
	return $dir;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

HTTP::OAI::DataProvider::Common - common FUNCTIONs for the dataProvider

=head1 VERSION

version 0.009

=head1 METHODS

=head2 my $modDir=$self->_modDir || die self->error;  

returns absolute path of module's directory or error. 

Carps on failure.

=head1 FUNCTIONS

=head2 carp argumentsLeft if @_;

OBSOLETE

argumentsLeft (in @_) stores just an error message in an attempt to unify the message
printed if the same error occurs.

=head2 $modDir=modDir();

returns the directory of the module, e.g.
/usr/lib/perl5/site_perl/5.10/HTTP/OAI/DataProvider

=head2 isScalar ($variable);

Dies if $variable is not scalar

=head2 valPackageName ($obj,'Package::Name');

Croak with error message if $obj is not blessed with Package::Name. You can specify
more than one package name. Continues if any of them machtes. You may think of 
package names as class types.

You pass more than one Package::Name. Test passes if $obj is one of them.

=head2 Debug "debug message";

First initialize Debug with codeRef:
	Debug (sub { my $msg=shift; print "$msg\n" if $msg});
		#or
	$config{debug}=sub { my $msg=shift; print "$msg\n" if $msg};
	Debug $config{debug};
Then use it
	Debug "message";

=head2 Warning "message";

Usage analogous to C<Debug>. For details see there.

=head2 testEnvironment ($signal, [$attach,] [$anotherAttach,] ...);

If $signal (optional) is 'config' absolute path of the configuration file is returned. 
Otherwise configuration directory (directory in which config resides) is returned.

If $attach is specified the string $attach is added to configuration directory. You
may add multiple $attach if you like.

If $signal is 'config' and $attach is added, $attach is ignored.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
