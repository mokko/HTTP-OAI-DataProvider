package HTTP::OAI::DataProvider::Transformer;

use warnings;
use strict;
#use HTTP::OAI;
use Carp qw/croak carp/;
use Dancer::CommandLine qw/Debug Warning/;

=head1 NAME

HTTP::OAI::DataProvider::Transformer

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::Transformer;
	my $t=new HTTP::OAI::DataProvider::Transformer (
		nativePrefix=> 'mpx',
		locateXSL=>'Salsa_OAI::salsa_locateXSL', #callback
	);
	my $dom=$t->toTargetPrefix ($targetPrefix,$dom);

=head1 DESCRIPTION

Little helper that applies an xslt on a $dom

=head1 METHODS

=head2 	my $dom=$t->toTargetPrefix ($targetPrefix,$dom);

=cut

sub new {
	my $class=shift;
	my %args=@_;
	my $self={};

	if (! $args{nativePrefix}) {
		croak "NativePrefix missing";
	}
	if (! $args{locateXSL}) {
		croak "locateXSL missing";
	}

	if ( $args{nativePrefix} ) {
		$self->{nativePrefix} = $args{ns_uri};
	}

	if ( $args{locateXSL} ) {
		$self->{locateXSL} = $args{ns_uri};
	}

	return (bless $self, $class);
}


sub toTargetPrefix {
	my $targetPrefix=shift;
	my $dom=shift;
	Debug "Enter toTargetPrefix ($targetPrefix, $dom)";
	#I need to know the nativeFormat to transform from native to native


	return $dom;

}

1;



