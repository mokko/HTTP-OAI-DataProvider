package HTTP::OAI::DataProvider::Transformer;

use warnings;
use strict;

#use HTTP::OAI;
use Carp qw/croak carp/;
use Dancer::CommandLine qw/Debug Warning/;
use XML::LibXSLT;

#the currently compiled xsl, see _cache_stylesheet
our %stylesheet_cache;

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

=head2 new

	my $t=new HTTP::OAI::DataProvider::Transformer (
		nativePrefix=> 'mpx',
		locateXSL=>'Salsa_OAI::salsa_locateXSL', #callback
	);

=cut

sub new {
	my $class = shift;
	my %args  = @_;
	my $self  = {};

	if ( !$args{nativePrefix} ) {
		croak "NativePrefix missing";
	}
	if ( !$args{locateXSL} ) {
		croak "locateXSL missing";
	}

	if ( $args{nativePrefix} ) {
		$self->{nativePrefix} = $args{nativePrefix};
	}

	if ( $args{locateXSL} ) {
		$self->{locateXSL} = $args{locateXSL};
	}

	return ( bless $self, $class );
}

=head2 	my $dom=$t->toTargetPrefix ($targetPrefix,$dom);

=cut

sub toTargetPrefix {
	my $self         = shift;    #transformer
	my $targetPrefix = shift;
	my $dom          = shift;

	#we imply that prefix is always able to be a hash

	#Debug "Enter toTargetPrefix ($targetPrefix)";
	#Debug "self: " . ref $self;
	#Debug "nativePrefix: " . $self->{nativePrefix};
	#Debug "locateXSL: " . $self->{locateXSL};
	#Debug "dom:" . ref $dom;

	if ( $targetPrefix eq $self->{nativePrefix} ) {
		#Debug "toTargetPrefix: native and target are eq";
		return $dom;
	}

	#Debug "We need a transformation";
	$self->_cache_stylesheet($targetPrefix);
	my $stylesheet = $stylesheet_cache{$targetPrefix};

	#my $results;
	if ($stylesheet) {
		$dom = $stylesheet->transform($dom) or carp "Problems";
	}

	return $dom;
}

sub _cache_stylesheet {
	my $self         = shift;
	my $targetPrefix = shift;

	my $style_doc;
	my $xslt = XML::LibXSLT->new();

	#if current style does not exist yet
	if ( !$stylesheet_cache{$targetPrefix} ) {

		#Debug "Update stylesheet cache (prefix:$targetPrefix)";

		# I need a callback which gets the target_prefix and returns the
		# fullpath to the xsl which transforms to new (non native) format
		no strict "refs";
		$style_doc = XML::LibXML->load_xml(
			location => $self->{locateXSL}($targetPrefix),
			no_cdata => 1
		);
		use strict "refs";

		#compile style
		my $stylesheet = $xslt->parse_stylesheet($style_doc);
		if ( !$stylesheet ) {
			croak "Internal error: This is an error, "
			  . "but I don't know which one yet";
		}

		#save in class variable
		$stylesheet_cache{$targetPrefix} = $stylesheet;

	}
}

1;

