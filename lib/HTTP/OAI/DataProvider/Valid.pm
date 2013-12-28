package HTTP::OAI::DataProvider::Valid;
{
  $HTTP::OAI::DataProvider::Valid::VERSION = '0.009';
}
# ABSTRACT: Validation of OAI documents

use strict;
use warnings;
use HTTP::OAI::DataProvider::Common qw(isScalar modDir valPackageName);
use XML::LibXML;
use Path::Class;
#use File::Spec;
use Moose;


sub BUILD {
	my $self = shift or die "Something's wrong!";

	#store xsd in module directory because it extends functionality of package

	my %load = (
		oaiXsd    => file ( modDir(), 'OAI-PMH.xsd' ),
		laxOaiXsd => file ( modDir(), 'OAI-PMH-lax.xsd' ),
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


sub validate {
	my $self = shift or die "Something's horribly wrong";
	my $doc  = shift or die "Error: Need doc!";
	return $self->_validate( 'oaiXsd', $doc );
}


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

__END__

=pod

=encoding UTF-8

=head1 NAME

HTTP::OAI::DataProvider::Valid - Validation of OAI documents

=head1 VERSION

version 0.009

=head1 METHODS

=head2 my $msg=$oai->validate($doc);

Returns the string "ok" if validation is ok and the error message on failure.

You can test for error:
	my $err=$oai->validate($doc)
	if ($err ne 'ok') {
		print "Error: $err\n";
	}

=head2 my $msg=$oai->validateResponse ($response[, 'lax']);

	if ($msg ne 'ok') {
		print "Error: $msg\n";
	}

=head2 my $msg=$oai->validateLax($doc);

I don't understand why the official OAI specific uses processContents="strict",
so I provide an alternative schema where this restriction is relaxed. 
Currently, I use it for getRecord responses.

=head2 Intro

This package starts its life without a proper plan. Just as a space for 
several validation related utilities.

my $doc=XML::LibXML->load_xml( location => $filename );
my $oai=new HTTP::OAI::DataProvider::Valid ();

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
