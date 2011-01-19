package HTTP::OAI::DataProvider::Transformer;

use warnings;
use strict;
#use HTTP::OAI;
use Carp qw/croak carp/;

=head1 NAME

HTTP::OAI::DataProvider::Transformer

=head1 SYNOPSIS

	use HTTP::OAI::DataProvider::Transformer;
	my $t=new HTTP::OAI::DataProvider::Transformer (
		nativePrefix=> 'mpx',

	);
	my $dom=$t->toTargetPrefix ($targetPrefix,$dom);

=head1 DESCRIPTION

Little helper that applies an xslt on a $dom

=head1 METHODS

=head2 	my $dom=$t->toTargetPrefix ($targetPrefix,$dom);

=cut

sub toTargetPrefix {
	my $targetPrefix=shift;
	my $dom;
	#I need to know the nativeFormat to transform from native to native


	return $dom;

}

1;



