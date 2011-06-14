package HTTP::OAI::DataProvider::GlobalFormats;
# ABSTRACT: Handle global metadata formats

use warnings;
use strict;
use HTTP::OAI;
use Carp qw/croak carp/;

=head1 SYNOPSIS

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


=head1 DESCRIPTION

A format is global if each and every record in a repository is available in it.
HTTP::OAI::Repository::Simple assumes that all formats are global, i.e. all
records available in all supported formats.

=head1 METHODS

=head2 my $globalFormats = HTTP::OAI::Repository::Simple::GlobalFormats->new();

=cut

sub new {
	my $class = shift;
	my $self  = {};
	$self->{lmfs} = HTTP::OAI::ListMetadataFormats->new;
	bless( $self, $class );
	return $self;
}

=head2	my $err= $globalFormats->register ( ns_prefix => $prefix,
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
	$self->{lmfs}->metadataFormat($mdf);

	#if anything goes wrong return error
	return ();
}

=head2	my $err=$globalFormats->unregister ($prefix);

Delete a format from global formats. On success, returns nothing or error on
failure.

=cut

sub unregister {
	my $self   = shift;
	my $prefix = shift;

	return "No prefix specified" if ( !$prefix );
	my $lmdf = new HTTP::OAI::ListMetadataFormats;

	foreach my $mdf ( $self->{lmdf}->metadataFormat ) {
		if ( $mdf->metadataPrefix ne $prefix ) {
			$lmdf->metadataPrefix($mdf);
		}
	}
	$self->{lmdf} = $lmdf;
	return ();
}

=head2 my $format=$globalFormats->get ($prefix);

Returns the HTTP::OAI::MetadataFormat in tone or more metadata formats which have been registered before.

If prefix, returns one format as HTTP::OAI::MetadataFormat. If no
prefix, it returns all defined as list of HTTP::OAI::MetadataFormat.

On failure or if no metadata format with that prefix is defined, returns
nothing.

Todo: Test. Is it possible that there are several formats of the same prefix?

=cut

sub get {
	my $self   = shift;
	my $prefix = shift;

	if ( !$prefix ) {
		return $self->{lmfs}->metadataFormat;
	}

	foreach my $mdf ( $self->{lmfs}->metadataFormat ) {
		if ( $mdf->metadataPrefix eq $prefix ) {
			return $mdf;
		}
	}

	return ();
}

=head2 my $l=$globalFormats->get_list

returns the HTTP::OAI::ListMetadataFormats object saved inside of the
HTTP::OAI::DataProvider::Simple::GlobalFormats.


=cut

sub get_list {
	my $self = shift;

	if ( $self->{'lmfs'} ) {
		return $self->{'lmfs'};
	}
	return ();
}

=head2 check_format_supported ($prefix);

my $e=check_format_supported ($prefix);

Check if metadataFormat $prefix is supported by this repository.

my $e=check_format_supported ($prefix);

if ($e) {
	#error
}

It's good to retrun the HTTP::OAI::Error object (and not a XML string)
so several errors can be returned.

=cut

sub check_format_supported {
	my $self   = shift;
	my $prefix = shift;

	#this can happen in case of empty resumption token
	#"verb=ListRecords&resumptionToken="
	#this should not happen, but anybody could just enter it
	if ( !$prefix ) {
		return new HTTP::OAI::Error(
			code    => 'badArgument',
			message => 'No prefix specified!',
		);
	}

	#print "check_format_supported ($prefix)";

	foreach my $mdf ( $self->{lmfs}->metadataFormat ) {
		if ( $prefix eq $mdf->metadataPrefix ) {

			#return empty handed on success
			return ();
		}
	}

	#print "metadataFormat not supported";
	return new HTTP::OAI::Error( code => 'cannotDisseminateFormat' );

}

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-http-oai-repository-simple-globalmetadataformats at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTTP-OAI-Repository-Simple-GlobalMetadataFormats>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTTP::OAI::Repository::Simple::GlobalMetadataFormats


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTTP-OAI-Repository-Simple-GlobalMetadataFormats>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTTP-OAI-Repository-Simple-GlobalMetadataFormats>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTTP-OAI-Repository-Simple-GlobalMetadataFormats>

=item * Search CPAN

L<http://search.cpan.org/dist/HTTP-OAI-Repository-Simple-GlobalMetadataFormats/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of HTTP::OAI::Repository::GlobalMetadataFormats
