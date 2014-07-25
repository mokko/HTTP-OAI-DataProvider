# ABSTRACT: Requirements for all engines
package HTTP::OAI::DataProvider::Engine::Interface;

use strict;
use warnings;
use Moose::Role;
use Carp qw(carp croak confess);


=head1 INTERFACE OVERVIEW

	#basic
	requires 'initDB';

	#query
	requires 'planChunking';
	requires 'queryChunk';

	#ingest
	requires 'storeRecord';
	
	#verb: identify
	requires 'earliestDate';
	requires 'granularity';

	#verb:listSets
	requires 'listSets';

=head1 SYNOPSIS FOR INHERITED METHODS

	with 'DP::Engine::Interface';
	$engine=new My::Engine;

	if ($engine->error) {
		print $engine->error;
	}
	$engine->resetError;
	
	if (valFileExists($file)) {
		#file exists
		#do something
	} else {
		#file does not exist
		print $engine->error;
	}
		
=head1 DESCRIPTION

This role describes an interface for all (specific) engines.

You only need this role when writing a database an engine for 
HTTP::OAI::DataProvider. 

DP::DataProvider creates DB::Engine object
 DP::Engine (class) consumes 
  DP::Engine::SQLite (role) which consumes  
   DP::Engine::Interface (role).

(Note: I use 'DP::' as an abbreviation for HTTP::OAI::DataProvider when 
convenient.)

=head2 Terminology

DP::Engine is the I<generic engine>.
DP::Engine::SQLite is an example of a specific engine.

If you like, think of the query engine as a frontend to the database. 

Database specific stuff (like SQL queries) goes into the specific engine.

=head1 SYNOPSIS

	package My::OAIDataProvider::MySQL;
		use Moose;
		with 'DP::Engine::Interface'; 
		...
	1;	

=head1 INTERFACE

=head2 QUERY ENGINE

=method $engine->planChunking
=method $engine->queryChunk

=cut

requires 'planChunking';
requires 'queryChunk';

=head2 INGEST INTERFACE 

=method $engine->storeRecord($record);

Expects a HTTP::OAI::Record and stores it in the database. This is called as
part of the ingestion process.

=cut

requires 'storeRecord';

=head2 NEEDED FOR INGESTER AND QUERY ENGINE

=method $self->init();

in case your engine needs to do something after its made (kind of like Moose's 
BUILD).

I use it now to initialize chunkCache. Then it calls ->initDB().

=cut
requires 'init';

=head2 IDENTIFY 

=method my $grany=$engine->granularity();

granularity returns one of the two strings of OAI specification:
 	'YYYY-MM-DDThh:mm:ssZ' or 'YYYY-MM-DD'
depending on the format of timestamps you return in HTTP::OAI::Header objects.

=cut

requires 'granularity';

=method  $timeStamp=$engine->earliestDate();

=cut

requires 'earliestDate';

=method my @setSpecs=$provider->listSets();

Expects nothing, returns a distinct list of setSpecs actually used in the 
store.

Called from DataProvider::ListSets.

=cut

=head2 LISTSETS

=method @setSpecs = $engine->listSets();

return list of distinct setSpecs used in store.

=cut

requires 'listSets';

###
###
###
### INHERITED METHODS (available in ingester AND in query engine)
###
###
###

=head1 DEAD SIMPLE PARAMETER VALIDATION AND ERROR MESSAGES

=method $self->valFileExists ($file);

Expects the path to a file, returns true if it exists or false if it doesn't.
Also sets an error message which is retrievable using $self->errorMessage:

	$self->valFileExists($file) or return;

Or

	if (!$self->valFileExists($file)) {
		print $self->error;
		return; #error (either $file or file don't exist)
	} 

Note: If $file is actually a file or a link, valFileExists counts it as found 
(even if link is a link to a directory). If $file is a directory it doesn't 
count as found.

=cut

sub valFileExists {
	my $self = shift or die "Need myself";
	my $file = shift;    #path to file, of course

	if ( !$file ) {
		$self->{error} = 'File not specified';
		return;    #failure
	}

	if ( !( -f $file or -l $file ) ) {
		$self->{error} = "File not found ($file)";
		return;    #failure
	}
	return 1;      #success
}

sub valIfExists {
	my $self = shift or die "Need myself";
	my $scalar = shift;    
	
	if (!$scalar) {
		$self->{error}='Scalar not specified';
		return;
	}
	return 1;
}

=method $msg=$self->error;

Returns last error message (a string) if there has been an error yet.

It returns nothing (failure) if no error message.

	#eg
	$engine->$method or croak $engine->error;

	if ($engine->error) {
		croak $engine->error;
	}

	$engine->error('param'); # error!
	
=cut

sub error {
	my $self = shift or die "Need myself";

	#not sure if I should warn in case errorMessage is called with parameters
	if (@_) {
		$self->{error} = 'errorMessage called with argument';
	}

	#if no error message there hasn't been an error yet
	if ( !$self->{error} ) {
		return;    #error
	}

	return $self->{error};
}

=method $engine->resetError
=cut

sub resetError {
	my $self = shift or die "Need myself";
	if ( $self->{error} ) {
		undef $self->{error};
	}
}

1;
