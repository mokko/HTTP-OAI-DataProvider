package HTTP::OAI::DataProvider::Database;
use strict;
use warnings;
use Moose::Role;

=head1 SYNOPSIS

You only need this when writing a database engine for 
HTTP::OAI::DataProvider:

	use Moose;
	with 'HTTP::OAI::DataProvider::Database'; #could also be ::Engine
	...
	
=head1 INTERFACE

=head2 $engine->storeRecord($record);

Expects a HTTP::OAI::Record and stores it in the database. This is called as
part of the ingestion process.

=cut

requires 'storeRecord';

=head2 my $grany=$engine->granularity();

granularity returns one of the two strings of OAI specification:
 	'YYYY-MM-DDThh:mm:ssZ' or 'YYYY-MM-DD'
depending on the format of timestamps you return in HTTP::OAI::Header objects.

=cut

requires 'granularity';

#
# INHERITED METHODS
#


1;
