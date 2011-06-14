package HTTP::OAI::DataProvider::SetLibrary;
BEGIN {
  $HTTP::OAI::DataProvider::SetLibrary::VERSION = '0.006';
}
# ABSTRACT: Handle set definitions

#use Dancer ':syntax';    #not absolutely necessary, only for debugging
use Dancer::CommandLine qw/Debug Warning/;
use warnings;
use strict;
use HTTP::OAI;
use Carp qw/croak/;
#use Data::Dumper qw/Dumper/;


sub new {

	#Debug "enter HTTP::OAI::DataProvider::SetLibrary new";
	my $self  = {};
	my $class = shift;

	$self->{ListSets} = new HTTP::OAI::ListSets;
	return bless( $self, $class );

	#I guess there are two possibilities
	#a) a hash with setSpec as key and HTTP::OAI::Set objects as values
	#b) HTTP::OAI::ListIdentifier with sets wrapped inside
	#in a)looping seems to be easier,but  code will be more cryptic
	#that's what encapsulation is for, right?

}


sub addSet {
	my $self = shift;    #a library object
	my $set  = shift;

	if ( !$set ) {
		return ();       #return empty handed without doing anything
	}

	#TODO: test if $set is HTTP::OAI::Set using ref

	if ( ref $set !~ /HTTP::OAI::Set/ ) {
		Warning "no HTTP::OAI::Set object";
		return ();       #return empty handed without doing anything
	}

	#add the new set to the ListSets object
	$self->{ListSets}->set($set);

	#Debug "return successfully";
	return 1;            #indicating success

}


sub addListSets {
	my $self     = shift;    #a library object
	my $ListSets = shift;    #new

	if ( !$ListSets ) {
		Warning "no listSet. Nothing to do!";
		return ();
	}

	if ( ref $ListSets !~ /HTTP::OAI::ListSets/ ) {
		Warning "no HTTP::OAI::ListSet object";
		return ();           #return empty handed without doing anything
	}

	#Debug "Enter addListSet ($ListSets)";

	if ( !$self->{ListSets} ) {
		die "This is strange. There should be an ListSets";
	}

	#alternatively I could also call addSet, but this can hardly be faster...
	while ( my $set = $ListSets->next ) {
		$self->{ListSets}->set($set);
	}
	return 1;    #successful;
}


sub expand {
	my $self     = shift;
	my @setSpecs = @_;      #naked setSpecs from store

	Debug "Enter setLibrary::expand";

	my $library_LS = $self->{ListSets};    #library sets

	#test if any ListSets in library at defined
	#wd be very strange if this test does not pass
	if ( !$library_LS ) {
		die "Very strange error";          #not initialized right
	}

	my $result_LS = new HTTP::OAI::ListSets;

	my %libraryTracker;
	while ( my $library_set = $library_LS->next ) {
		foreach my $setSpec (@setSpecs) {
			if ( $library_set->setSpec eq $setSpec ) {
				$result_LS->set($library_set);
				$libraryTracker{$setSpec} = 1;
			}
		}
	}

	#If a setSpec is not defined in the library, it should still be in result
	#i.e. it is not enough to identify common elements in both sets.
	#We also want to find naked setSpecs (specific records, but not in library)

	foreach my $setSpec (@setSpecs) {
		if (!$libraryTracker{$setSpec}) {
			#if this setSpec is not yet in the response then it will have to go
			#naked
			my $s=new HTTP::OAI::Set;
			$s->setSpec ($setSpec);
			$result_LS->set($s);
		}

	}

	return $result_LS;
}


sub show {
	my $self     = shift;
	my $ListSets = $self->{ListSets};
	my $out;

	while ( my $set = $ListSets->next ) {
		if ( $set->setSpec ) {
			$out = $set->setSpec . ":\n";
		}
		if ( $set->setName ) {
			$out .= " setName: '" . $set->setName . "'\n";
		}
		foreach my $setDescription ( $set->setDescription ) {
			$out .= " setDescription: '" . $setDescription . "'\n";
		}
	}

	return $out;
}


sub toListSets {
	my $self = shift;
	Debug "Enter toListSets\n";

	return $self->{ListSets};
}


1;    # End of HTTP::OAI::SetLibrary. Perl Dancer is still cool!


__END__
=pod

=head1 NAME

HTTP::OAI::DataProvider::SetLibrary - Handle set definitions

=head1 VERSION

version 0.006

=head1 SYNOPSIS

Separate sets and their definition. Access only sets that are actually present
in your repository.

    use HTTP::OAI::Set;
    use HTTP::OAI::Repository::SetLibrary;

	#make a HTTP::OAI::Set object as described in that module
	my $s=new HTTP::OAI::Set->new();
	$s->setSpec('a setSpec');
	$s->setName('a name');
	$s->setDescription('a description');

	#make a set library
    my $library = HTTP::OAI::SetLibrary->new();

	#add the HTTP::OAI::Set to the library
	$library->addSet($s);

	#show library contents as string (for debugging)
	print $library->show;

	#a list of setSpecs in your repository


	#e.g. when you use HTTP::OAI::DataProvider::Simple
	my @setSpecs=$cache->HTTP::OAI::DataProvider::Simple::listSets;

	#filter library to return only those sets
	#mentioned in @setSpecs and add name and descriptions
	#returns a HTTP::OAI::ListSet object
	my $listSets=$library->expand(@setSpecs);

	#for completeness
	my $listSets=$library->toListSets;

=head1 DESCRIPTION

Sets have identifier-like 'names' called setSpec (see OAI specification).
They can also have more descriptive (and usually longer) names and a
description. Sets are associated with records in the OAI header.

You likely want to store information on name and description somewhere.
SetLibrary provides an object to store and retrieve the set information.

HTTP::OAI::SetLibrary also attempts to provide a comfortable way to retrieve
only those sets which are actually present in your repository (and not all
sets defined in the library).

=head1 CONTEXT

In my setup, I parse a yaml configuration file using Dancer (perldancer.org)
to pass info from the config to SetLibrary.

If my OAI data provider receives a ListSet request, it is not supposed to
show all sets which have been defined in the library, but only those which
actually come up in the data currently present in the repository.

I search for the present lists using the listSets method from
HTTP::OAI::DataProvider::Simple and filter the library to return only those which
actually come up in the data.

The sets will then no longer be setSpec strings only, but 'complete', i.e.
have the name and the description defined in the library. Return value is a
HTTP::OAI::ListSets object which can be easily turned into output.

=head1 METHODS

=head2 my $s=new HTTP::OAI::SetLibrary->new();

Creates a new HTTP::OAI::SetLibrary object. You can optionally specify a hashref
containing initial set info for the library. At the moment, I use setSpec for key
and name for value which is likely to change since description not yet supported.
This should be a good format to specify the info in YAML.

Some more examples:

my %library={
	test=>'longer name',
}

new HTTP::OAI::SetLibrary->new(\%library);

=head2 $library->addSet($s);
Add a single HTTP::OAI::Set object to a library

Logic-wise I could also add a listSets object, but I don't do this here.

TODO: On failure return something or not?

=head2 $library->addListSets($s);
Adds a HTTP::OAI::ListSet object (possibly containing multiple sets) to a Set
library.

TODO: Test
TODO: On failure return something or not?

=head3 my $ListSets=$library->expand(@setSpecs)

Expects an array of setSpecs (as strings). Returns a HTTP::OAI::ListSet object
which contains setDescription and setName for each of the input setSpecs which
are defined in the setlibrary. In other words:it adds setName and setDescription
to naked setSpecs (where defined, of course).

Old description:
Compare sets defined in the library and the ones passed over via array. It
returns a HTTP::OAI::ListSet object which has only those sets which are mentioned
in the array @sets. The returned ListSet has the setName and setDescriptions
from the library for those sets.

If a set is mentioned in a header which is not defined in the library, then this
set will simply have no name and description. No error will be raised.

TODO: What to do with errors?

=head2 my $string=$library->show();

Output library information as string. For example for debugging.

setSpec:
 setName: 'abc'
 setDescription: 'edf'

=head2 my $listSets=$library->toListSets;

Just returns the whole library as a HTTP::OAI::ListSets object.

=head1 SEE ALSO

The Open Archives Initiative Protocol for Metadata Harvesting,
http://www.openarchives.org/OAI/openarchivesprotocol.html

Tim Brody's excellent HTTP::OAI available on a CPAN near you.

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-http-oai-setlibrary at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTTP-OAI-SetLibrary>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTTP::OAI::SetLibrary

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTTP-OAI-SetLibrary>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTTP-OAI-SetLibrary>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTTP-OAI-SetLibrary>

=item * Search CPAN

L<http://search.cpan.org/dist/HTTP-OAI-SetLibrary/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

