package HTTP::OAI::DataProvider::GlobalFormats;

# ABSTRACT: Handle global metadata formats

use warnings;
use strict;
use HTTP::OAI;
use Carp qw/croak carp/;

=head1 DESCRIPTION / RATIONALE

A format is global if each record in the repository is available in it. A 
repository with global formats serves each record it stores in each format
it knows.

GlobalFormats keeps track of a bunch of formats and provides a simple method 
to test if this format is supported.

Currently, GlobalFormats creates proper HTTP::OAI::ListMetadataFormats objects, 
but I wonder if it would not be enough if we store a simple hash or hashref 
with the metadataPrefixes. That would make the whole package unnecessary.

This works only if prefix identify metadataFormats unambiguously.

=head1 OLD SYNOPSIS

    use HTTP::OAI::DataProvider::GlobalFormats;

    my $globalFormats = HTTP::OAI::DataProvider::GlobalFormats->new();

	my $err=$globalFormats->register ( ns_prefix => $prefix,
		ns_uri => $uri, ns_schema => $location
	);

	if ($err) {
		#there is an error
		return $err;
	}

	my $err=check_format_supported ($prefix);

	if ($err) {
		#error is HTTP::OAI::Error with code CannotDisseminateFormat
		return $err;
	}

	#TODO test
	my $err=$globalFormats->unregister ($prefix);
	my $format=$globalFormats->get ($prefix);
	my @formats=$globalFormats->get ();
	my $lmdf=$globalFormats->get_list ();

=method my new $globalFormats = HTTP::OAI::Repository::Simple::GlobalFormats();

=cut

sub new {
	my $class = shift;
	my $self  = {};
	$self->{lmf} = HTTP::OAI::ListMetadataFormats->new;
	bless $self, $class;
	return $self;
}

=method	my $err= $globalFormats->register ( ns_prefix => $prefix,
		ns_uri    => $uri,
		ns_schema => $location
	);
=cut

sub register {
	my $self = shift;
	my %args = @_;

	if ( !$args{ns_prefix} or !$args{ns_schema} or !$args{ns_uri} ) {
		croak "Cannot register format!";
	}

	my $mdf = new HTTP::OAI::MetadataFormat;

	#I don't like those names so I use different ones
	$mdf->metadataPrefix( $args{ns_prefix} );
	$mdf->schema( $args{ns_schema} );
	$mdf->metadataNamespace( $args{ns_uri} );

	#
	$self->{lmf}->metadataFormat($mdf);

	return 1;    #success
}

=method	my $err=$globalFormats->unregister ($prefix);

Delete a format from global formats. On success, returns nothing or error on
failure.

=cut

sub unregister {
	my $self = shift;
	my $prefix = shift or croak "No prefix specified";

	my $newList = new HTTP::OAI::ListMetadataFormats;

	if ( !$self->{lmf} ) {
		croak 'Internal $self->{lmf} doesn\'t exist!';
	}

	foreach my $format ( $self->{lmf}->metadataFormat ) {
		if ( $format->metadataPrefix ne $prefix ) {
			$newList->metadataPrefix($format);
		}
	}
	$self->{lmf} = $newList;
	return 1;    #success
}

=method my $format=$globalFormats->get ($prefix);

$prefix is optional.

If prefix specified and exists in $globalFormats, return format as 
HTTP::OAI::MetadataFormat. If no prefix specified, it is unclear what this
method does: 
-should it return one HTTP::OAI::MetadataFormat or several 
 HTTP::OAI::MetadataFormat as a list?
-should it return ListMetadataFormats?

Currently it returns the next MetadataFormat.

On failure or if no metadata format with that prefix is defined, returns
nothing.

=cut

sub get {
	my $self   = shift;
	my $prefix = shift;

	if ( !$prefix ) {
		return $self->{lmf}->metadataFormat;
	}

	foreach my $mdf ( $self->{lmf}->metadataFormat ) {
		if ( $mdf->metadataPrefix eq $prefix ) {
			return $mdf;
		}
	}

	return;    #failure
}

=method my $lmf=$globalFormats->getList

returns the HTTP::OAI::ListMetadataFormats object saved inside of the
HTTP::OAI::DataProvider::GlobalFormats.

Should this method be called getList instead?

=cut

sub getList {

	my $self = shift;

	if ( $self->{'lmfs'} ) {
		return $self->{'lmfs'};
	}
	return ();

}

sub get_list {
	warn "deprecated! Please use getList instead!";
	goto &getList;
}

=method my $e=$globalFormats->check_format_supported ($prefix); 

Check if metadataFormat $prefix is supported by this repository.

my $e=check_format_supported ($prefix);

if ($e) {
	#error
}

It's good to retrun the HTTP::OAI::Error object (and not a XML string)
so several errors can be returned.

=cut

sub checkFormatSupported { goto &check_format_supported }

sub check_format_supported {
	my $self   = shift;
	my $prefix = shift
	  or return new HTTP::OAI::Error(
		code    => 'badArgument',
		message => 'No prefix specified!',
	  );

	#this can happen in case of empty resumption token
	#"verb=ListRecords&resumptionToken="
	#this should not happen, but anybody could just enter it

	#print "check_format_supported ($prefix)";

	foreach my $mdf ( $self->{lmf}->metadataFormat ) {
		if ( $prefix eq $mdf->metadataPrefix ) {

			#return empty handed on success
			return ();
		}
	}

	#print "metadataFormat not supported";
	return new HTTP::OAI::Error( code => 'cannotDisseminateFormat' );

}

1;    # End of HTTP::OAI::Repository::GlobalMetadataFormats
