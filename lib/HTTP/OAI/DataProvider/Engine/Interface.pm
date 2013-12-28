package HTTP::OAI::DataProvider::Engine::Interface;
{
  $HTTP::OAI::DataProvider::Engine::Interface::VERSION = '0.009';
}
# ABSTRACT: my first interface
use strict;
use warnings;
use Moose::Role;
use Carp qw(carp croak confess);



requires 'planChunking';
requires 'queryChunk';


requires 'storeRecord';

requires 'init';


requires 'granularity';


requires 'earliestDate';



requires 'listSets';

###
###
###
### INHERITED METHODS (available in ingester AND in query engine)
###
###
###


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


sub resetError {
	my $self = shift or die "Need myself";
	if ( $self->{error} ) {
		undef $self->{error};
	}
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

HTTP::OAI::DataProvider::Engine::Interface - my first interface

=head1 VERSION

version 0.009

=head1 SYNOPSIS

	package My::OAIDataProvider::MySQL;
		use Moose;
		with 'DP::Engine::Interface'; 
		...
	1;	

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

=head1 METHODS

=head2 $engine->planChunking
=method $engine->queryChunk

=head2 $engine->storeRecord($record);

Expects a HTTP::OAI::Record and stores it in the database. This is called as
part of the ingestion process.

=head2 $self->init();

in case your engine needs to do something after its made (kind of like Moose's 
BUILD).

I use it now to initialize chunkCache. Then it calls ->initDB().

=head2 my $grany=$engine->granularity();

granularity returns one of the two strings of OAI specification:
 	'YYYY-MM-DDThh:mm:ssZ' or 'YYYY-MM-DD'
depending on the format of timestamps you return in HTTP::OAI::Header objects.

=head2 $timeStamp=$engine->earliestDate();

=head2 my @setSpecs=$provider->listSets();

Expects nothing, returns a distinct list of setSpecs actually used in the 
store.

Called from DataProvider::ListSets.

=head2 @setSpecs = $engine->listSets();

return list of distinct setSpecs used in store.

=head2 $self->valFileExists ($file);

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

=head2 $msg=$self->error;

Returns last error message (a string) if there has been an error yet.

It returns nothing (failure) if no error message.

	#eg
	$engine->$method or croak $engine->error;

	if ($engine->error) {
		croak $engine->error;
	}

	$engine->error('param'); # error!

=head2 $engine->resetError

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

=head1 INTERFACE

=head2 QUERY ENGINE

=head2 INGEST INTERFACE 

=head2 NEEDED FOR INGESTER AND QUERY ENGINE

=head2 IDENTIFY 

=head2 LISTSETS

=head1 DEAD SIMPLE PARAMETER VALIDATION AND ERROR MESSAGES

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
