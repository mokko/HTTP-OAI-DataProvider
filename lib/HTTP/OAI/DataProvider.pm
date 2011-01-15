package HTTP::OAI::DataProvider;

use warnings;
use strict;
use XML::SAX::Writer;
use Carp qw/croak carp/;

#should be only temporary, for warning and debug
#use Dancer ':syntax'; #this module should abstract from Dancer
use Dancer::CommandLine qw/Debug Warning/;

#for easier development, will go away later
use lib '/home/Mengel/projects/HTTP-OAI-DataProvider/lib';

#verbs - this time without exporter. Yay!

#I hope not that I don't need GlobalFormats
use HTTP::OAI::DataProvider::GlobalFormats;

=head1 NAME

HTTP::OAI::DataProvider - A flexible OAI data provider

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Initialize a data provider the with engine of your choice. There a detailed
engine-specific configuration requirements not shown here. See engine
for further information:

	#possible alternative:
    use HTTP::OAI::DataProvider;
	use HTTP::OAI::DataProvider::SQLite;

    my $provider = HTTP::OAI::DataProvider->new(%options);

	#engine interface
    #1) init
    my $engine = HTTP::OAI::DataProvider::SQLite->new(%options);
	#2) various
	$engine->listSets
	$engine->query(%param);

	#3)verbs
	my $response=$engine->GetRecord(%param);
	#response is either
	#a)a HTTP::OAI::Response
	#b)an xml string
	#c)an error
	#analogous for other verbs
	#TODO: Decide on a or b

Digest source data
	# make sure that data is in the right form and in the right place
    # see engine of your choice for more information, e.g.
	my $err=$engine->digest_single (source=>$xml_fn, mapping=>&mapping);

Verbs
	$response=$provider->$verb($params)
	#response is HTTP::OAI object and not XML

Output
	#TODO (there have been some complications with it in its last
	#incarnation, right?)

	my $xml=$response->toXML

Error checking/TODO
	my $e=$response->isError
	if ($response->isError) {
		#in case of error do this
	}

Debugging
	I use Dancer::CommandLine

	Debug "message";
	Warning "message";

=head1 OAI DATA PROVIDER FEATURES

supported
- hopefully tests and all OAI verbs of the specification version 2

not supported
- resumptionTokens
- hierarchical sets

=head1 COMPONENTS

Currently, the data provider is split in three components which are introduced
in this section: the backend, the frontend and the engine.

BACKEND/FRONTEND

This module attempts to provide a neutral backend for your data provider. It is
not a complete data provider. You will need a simple frontend which handles
HTTP requests and triggers this backend. I typically use Dancer as frontend,
see Salsa_OAI for an example:

Apart from configuration and callbacks your frontend could look like this

any [ 'get', 'post' ] => '/oai' => sub {
	if ( my $verb = params->{verb} ) {
		no strict "refs";
		my $respons=$dp->$verb( params() );
		return $response->toXML;
	}
};
dance;
true;

OVERVIEW

The engine
-provides a data store,
-a header store and
-the means to digest source data and to
-query both header and data store
-public functions/methods are those which aremeant to be called by the backend.

The backend is
-should not depend on Dancer or any other web framework
-should not depend on a specific metadata format
-should perform most error checks prescribed by the OAI specification.
-public functions/methods are those which are meant to be called from the frontend.

The frontend
-potentially employs a web framework like Dancer
-provides ways to work with specific metadata formats (mappings)
-parses configuration data and hands it over to backend
-includes most or all callbacks

=head1 MORE TERMINOLOGY

I differentiate between SOURCE DATA, DATA STORE and a HEADER STORE.
(For historically reasons, I sometimes refer to the header store as header cache).

"Header" always refers to OAI Headers as specified in the OAI PMH. Sometimes, I
add the letters OAI, sometimes not without indicating any difference in
meaning.

There has to be a way to obtain header information. Typically you will want to
specify rules (using callbacks) which extract OAI header info from the source
data. You might also want to create header information, e.g. when it is
missing, but for simplicity I just call any generation of header data
EXTRACTION.

You could say that the callbacks which extract header data implement some kind
of a mapping. But potentially, you could have many different mappings, so I
avoid this term here. I treat this mapping like configuration data. Therefore,
I locate it in the front end; the backend only has to document these callbacks.

Global MetadataFormats: A metadataFormat is global if any item in the
repository is available in this format. Currently HTTP::OAI::DataProvider
supports only global metadata formats.

#
#TODO
#
	$provider->registerFormat(ns_prefix => $prefix, ns_uri => $uri,
		ns_schema => $location);

	# beyond this module or as part of this module?
	# This module needs a way to check if metadataFormat is supported. The
	# is info can be anywhere. I have it in Dancer config. Suggesting I need
	# a callback to SalsaOAI. I plan on using globalFormats. Ideally
	# globalFormats would not be part of DataProvider, but maybe this goes
	# to far for the moment.
	# isMetadataFormatSupported($prefix)
	# returns either 1 for true or nothing for false. I could initilize
	# globalFormats in Salsa_OAI and then provide

	#do I really need registerFormat in this namespace or can I leave that to
	#GlobalFormats: something like
	use HTTP::OAI::GlobalFormats;
    my $globalFormats = HTTP::OAI::DataProvider::GlobalFormats->new();


=head1 THE PLAN

The predecessor of this module was HTTP::OAI::DataProvider::Simple. There, the
idea was to implement a simple data provider with flat files and in-memory
cache.

It quickly became clear that this implementation does not scale well. This
solution requires a lot of memory and tends to be slow. It's just one notch up
from static repository.

This version abstracts a little different to allow the use of different
engines. It adds the concept of the engine.

Currently, I am working on a memory engine (uses flat xml files and stores OAI
header information in memory) and a SQLite engine, which stores both header
information and metadata in SQLite. This mainly splits off the error checks
prescribed by the OAI specification from the actual metadata munging. The
former takes place in the backend (this module), the latter in the engines (see
engine modules for specifics).

This module tries not to rely on any specific webframework, but it might rely
in the beginning at least on Dancer, a fabulous light-weight and heavy-duty
framework, see Github.com.

=head1 HOW TO WRITE YOUR OWN ENGINE

This needs to be here, since it doesn't fit in a specific engine or it could be
separate document.

Anyways:Todo

=head1 METHODS - INITIALIZATION

=head2 my $provider->new (%options);

Initialize the HTTP::OAI::DataProvider object with the options of your choice.

On failure return nothing; in case this the error is likely to occur during
development and not during runtime it may also croak.

=head3 OPTIONS

only options not otherwise explained?

isMetadaFormatSupported=>Callback,

	The callback expects a single prefix and returns 1 if true and nothing
	when not supported. Currently only global metadataFormats, i.e. for all
	items in repository. This one seems to be obligatory, so croak when
	missing.

xslt=>'path/to/style.xslt',

	Adds this path to HTTP::OAI::Repsonse objects to modify output in browser.
	See also _init_xslt for more info.

	Except engine information, nothing no option seems to be required and it is
	still uncertain, maybe even unlikely if engine will be option at all.
	(Alternative would be to just to use the engine.)


=cut

sub new {
	my $class = shift;
	my %args  = @_;

	#TODO:
	#probably not a secure thing to do:
	my $self = \%args;

	bless( $self, $class );
	return $self;
}

#should digest_single be part of this module or of the engine?
#it would be less fragile if engine operates on its own

#
#
#

=head1 METHODS - VERBS

=head2 my $result=$provider->GetRecord(%params);

Todo: Might become AUTOLOAD? Better than this senseless code duplication!

=cut

sub GetRecord {
	my $self   = shift;
	my %params = shift;

	return ( HTTP::OAI::DataProvider::GetRecord->do( $self, %params ) );
}

=head2 my $response=$provider->Identify();

Simply a callback. It could be located in the frontend and return Identify
information from a configuration file.

Callback should be passed over to HTTP::OAI::DataProvider during
initialization with option Identify, e.g.
	my $provider = HTTP::OAI::DataProvider->new(
		#other options
		#...
		Identify      => 'Salsa_OAI::salsa_Identify',
	);

This method expects HTTP::OAI::Identify object from the callback and will
prompty return a xml string.

=cut

sub Identify {

	my $self = shift;
	Debug "Enter Identify (HTTP::OAI::DataProvider)";
	no strict "refs";

	#might change and loose args
	if ( !$self->{Identify} ) {
		return
		  "Error: Identify callback seems not to exist. Check initialization "
		  . "of HTTP::OAI::DataProvider";
	}

	#call the callback for actual data
	my $identify_cb = $self->{Identify};
	my $response    = $self->$identify_cb;
	use strict "refs";

	#Debug "I am back from callback";

	if ( ref $response eq 'HTTP::OAI::Identify' ) {
		if ( $self->{xslt} ) {
			$response->xslt( $self->{xslt} );
		}

		# todo: will probably need to go somewhere else
		my $xml;
		$response->set_handler( XML::SAX::Writer->new( Output => \$xml ) );
		$response->generate;
		return $xml;

	}
	croak 'Return value is not of type HTTP::OAI::Identify';
}

=head2 ListMetadataFormats (identifier);

"This verb is used to retrieve the metadata formats available from a
repository. An optional argument restricts the request to the formats available
for a specific item." (the spec)

HTTP::OAI::DataProvider only knows global metadata formats, i.e. it assumes
that every record is available in every format supported by the repository.

ARGUMENTS
-identifier (optional)

ERRORS
-badArgument - in validate_request()
-idDoesNotExist - here
-noMetadataFormats - here

=cut

sub ListMetadataFormats {
	my $self   = shift;
	my $params = _hashref(@_);

	Warning 'Enter ListMetadataFormats';
	if ( $params->{identifier} ) {
		Debug 'with id' . $params->{identifier};
	}

	my $engine        = $self->{engine};          #TODO test
	my $globalFormats = $self->{globalFormats};

	#
	# Error handling
	#

	#only if there is actually an identifier
	#TODO
	if ( my $identifier = $params->{identifier} ) {

		my $header = $engine->findByIdentifier($identifier);
		if ( !$header ) {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'idDoesNotExist' ) );
		}
	}

	#Metadata Handling
	my $lmfs = $globalFormats->get_list();
	my @mdfs = $lmfs->metadataFormat();

	#check if noMetadataFormats
	if ( @mdfs == 0 ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noMetadataFormats' ) );
	}

	#
	# Return
	#

	$lmfs = $self->_init_xslt($lmfs);
	return $lmfs->toDOM->toString;
}

sub ListIdentifiers {
	my $self   = shift;
	my %params = shift;

	return ( HTTP::OAI::DataProvider::ListIdentifiers->do( $self, %params ) );
}

sub ListRecords {
	my $self   = shift;
	my %params = shift;

	return ( HTTP::OAI::DataProvider::ListRecords->do( $self, %params ) );

}

sub ListSets {
	my $self   = shift;
	my %params = shift;

	return ( HTTP::OAI::DataProvider::ListSets->do( $self, %params ) );
}

#
#
#

=head1 METHODS - VARIOUS PUBLIC UTILITY FUNCTIONS

check error, display error, warning, debug etc.



#
# PRIVATE STUFF
#

=head1 PRIVATE METHODS

HTTP::OAI::DataProvider is to be used by frontend developers. What is not meant
for them, is private.

=head2 my $params=_hashref (@_);

Little thingy that transforms array of parameters to hashref and returns it.

=cut

sub _hashref {
	my %params = @_;
	return \%params;
}

=head2 $obj= $self->_init_xslt($obj)

  For an HTTP::OAI::Response object ($obj), sets the stylesheet to the value
  specified during init. This assume that there is only one stylesheet.

  This may be a bad name, since not specific enough. This xslt is responsible
  for a nicer look and added on the top of reponse headers.

=cut

sub _init_xslt {
	my $self = shift;
	my $obj  = shift;    #e.g. HTTP::OAI::ListRecord
	if ( !$obj ) {
		Warning "init_xslt called without a object!";
		return ();
	}

	#todo: could loose the args
	if ( $self->{xslt} ) {
		$obj->xslt( $self->{xslt} );
	}
	return $obj;
}

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

Please use Github.com Issue queue to report bugs
Todo: Link

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTTP::OAI::DataProvider


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTTP-OAI-DataProvider-SQLite>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTTP-OAI-DataProvider-SQLite>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTTP-OAI-DataProvider-SQLite>

=item * Search CPAN

L<http://search.cpan.org/dist/HTTP-OAI-DataProvider-SQLite/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of HTTP::OAI::DataProvider
