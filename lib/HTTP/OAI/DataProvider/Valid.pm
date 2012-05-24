package HTTP::OAI::DataProvider::Valid;
# ABSTRACT: Validation of OAI documents

use strict;
use warnings;
use HTTP::OAI::DataProvider::Common qw(isScalar modDir valPackageName);
use XML::LibXML;
use File::Spec;
use Moose;

=head2 Intro

This package starts its life without a proper plan. Just as a space for 
several validation related utilities.

my $doc=XML::LibXML->load_xml( location => $filename );
my $oai=new HTTP::OAI::DataProvider::Valid ();

=cut

sub BUILD {
	my $self = shift or die "Something's wrong!";

	#store xsd in module directory because it extends functionality of package

	my %load = (
		oaiXsd    => File::Spec->catfile( modDir(), 'OAI-PMH.xsd' ),
		laxOaiXsd => File::Spec->catfile( modDir(), 'OAI-PMH-lax.xsd' ),
	);

	foreach my $key ( keys %load ) {
		my $file = $load{$key};

		if ( !-f $file ) {
			die "XSD file not found!";
		}

		$self->{$key} = XML::LibXML::Schema->new( location => $file )
		  or die "Error: Cant parse schema!";
	}
}

=method my $msg=$oai->validate($doc);

Returns the string "ok" if validation is ok and the error message on failure.

You can test for error:
	my $err=$oai->validate($doc)
	if ($err ne 'ok') {
		print "Error: $err\n";
	}

=cut

sub validate {
	my $self = shift or die "Something's horribly wrong";
	my $doc  = shift or die "Error: Need doc!";
	return $self->_validate( 'oaiXsd', $doc );
}

=method my $msg=$oai->validateResponse ($response[, 'lax']);

	if ($msg ne 'ok') {
		print "Error: $msg\n";
	}
=cut

sub validateResponse {
	my $self     = shift or die "Something's horribly wrong";
	my $response = shift or die "Error: Need response!";
	my $lax = shift;    #optional

	isScalar($response);
	my $doc = XML::LibXML->load_xml( string => $response );
	my $schema = 'oaiXsd';
	$lax && $lax eq 'lax' ? $schema = 'laxOaiXsd' : 1;
	#print "schema:$schema\n";
	return $self->_validate( $schema, $doc );
}

=method my $msg=$oai->validateLax($doc);

I don't understand why the official OAI specific uses processContents="strict",
so I provide an alternative schema where this restriction is relaxed. 
Currently, I use it for getRecord responses.

=cut

sub validateLax {
	my $self = shift or die "Something's horribly wrong";
	my $doc  = shift or die "Error: Need doc!";
	return $self->_validate( 'laxOaiXsd', $doc );
}

#
# internal
#

sub _validate {
	my $self = shift or die "Something's horribly wrong";
	my $type = shift or die "Error: Need type!";
	my $doc  = shift or die "Error: Need doc!";

	if ( !$self->{$type} ) {
		die "Error: After self inspection I find thast I am not of that type";
	}

	valPackageName( $doc,           'XML::LibXML::Document' );
	valPackageName( $self->{$type}, 'XML::LibXML::Schema' );

	eval { $self->{$type}->validate($doc); };
	if ($@) {
		return $@;
	}
	else {
		return 'ok';
	}
}

__PACKAGE__->meta->make_immutable;
1;
