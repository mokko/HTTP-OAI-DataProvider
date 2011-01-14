package HTTP::OAI::DataProvider::ListMetadataFormats;

use Dancer ':syntax'; #for warning or debug!
use warnings;
use strict;

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

sub do {
	my $self = shift;
	my %params=@_;

	warning 'Enter ListMetadataFormats';
	if (params->{identifier}) {
		debug 'with id'.params->{identifier}
	}

	my $header_cache  = $self->{headers};         #TODO test
	my $globalFormats = $self->{globalFormats};

	#
	# Error handling
	#

	#only if there is actually an identifier
	if ( my $identifier = params->{identifier} ) {

		my $header = $header_cache->findByIdentifier($identifier);
		if ( !$header ) {
			return $self->err2XML(
				new HTTP::OAI::Error( code => 'idDoesNotExist' ) );
		}
	}

	#Metadata Handling
	my $lmfs = $globalFormats->get_list();
	my @mdfs = $lmfs->metadataFormat();

	if ( @mdfs == 0 ) {
		return $self->err2XML(
			new HTTP::OAI::Error( code => 'noMetadataFormats' ) );
	}

	#
	# Return
	#

	$lmfs=$self->init_xslt ($lmfs);
	return $lmfs->toDOM->toString;
}



1; #HTTP::OAI::DataProvider::ListMetadataFormats;
