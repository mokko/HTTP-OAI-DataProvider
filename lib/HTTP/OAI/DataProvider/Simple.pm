package HTTP::OAI::DataProvider::Simple;
use Dancer ':syntax';

use warnings;
use strict;
use YAML::Syck qw/Dump LoadFile/;
use XML::LibXML;
use HTTP::OAI;
use HTTP::OAI::Repository qw/:validate/;
use Carp qw/cluck croak carp/;
use Exporter;
# our requires at least perl56
our @EXPORT_OK = qw(import_single import_dir load_cache write_cache);

=head1 NAME

HTTP::OAI::DataProvider::Simple - Create/query a file based OAI header cache

=head1 SYNOPSIS

1) Creating new cache
	use HTTP::OAI::DataRepository::Simple;
		qw/import_single import_dir/;

	#describe native metadata format here
	my $engine=new HTTP::OAI::DataProvider::Simple(
		ns_prefix=>$prefix, ns_uri=$uri
	);

	#load a single xml source file, $err empty on success
	#mapping: extracts header info from XML
	my $err=$engine->import_single (source=>$xml_fn, mapping=>&mapping);
	my $err=$engine->import_dir (source=>$xml_fn, mapping=>&mapping);

	#Example:write your own (TODO test code)
	sub mapping {
		my $doc=shift;
		my $id=$doc->findvalue('item/@id');
		my $datestamp=$doc->findvalue('item/@datestamp');
		return new HTTP::OAI::Header (identifier=>$id, datestamp=>$datestamp);
	}

	#Write xml/yaml file cache
	$cache->write_cache($cache_fn);

2) Using the cache
	use HTTP::OAI::DataProvider::Simple::HeaderCache qw/load_cache/;
	my $engine=load_cache($cache_fn);
	$engine->load_cache($cache_fn);

	#Querying: query cache
	$result=$engine->query(from=>$from, until=>$until, set=>$set);
	#metadataPrefix=>$mdp not supported, use GlobalFormats instead
	#TODO?

	#find a specific header by identifier
	my $header=$engine->findByIdentifier($identifier)

	#Do things with sets
	#list sets: list (setSpec) in the cached headers
	my @all_sets_in_cache=$engine->listSets
	#TODO: hierarchy of Sets???

	#Looping thru headers. Foreach could be inefficint.
	foreach my $h ($engine->loop) {
		# do something with $h
		# $h is HTTP::OAI::Header
	}

	#could be inefficient
	@count=$engine->loop;

	#errors
	my @return=$cache->isError; #returns errors list of HTTP::OAI::Error
	my $str=$cache->errorsToXML;#returns errors as XML fit to output

	#alternative
	if ($cache->isError){
		print $cache->errorsToXML;
	}

	#output helper
	my $str=$cache->toXML; #all the news that's fit to print

=head1 DESCRIPTION

    OAI specification allows to query for metadataPrefix, identifier, date
    and resumptionToken. For GetRecords and ListRecords you need to find
    records by identifier and for ListSets you need to know which sets exist
    in your repository. It is certainly not by chance that all of this
    information is stored in the OAI headers. If you know the header, you
    can answer the queries.

    HTTP::OAI::HeaderCache makes it easy to cache header info as yaml file
    on disk, read it to memory. Depending on your set-up this could speed up
    your repository (esp. with data residing
    in flat file(s), i.e. without db).

=head1 OAI ERROR MESSAGES

    HTTP::OAI::HeaderCache tries to provide the error messages specified in
    the OAI specification where appropriate. It CANNOT test for 'noSetHierarchy'.
    You have to do so yourself if your repository does not support sets. This
    documentation should make explicit for which errors it tests.

	Also headers do not contain info about the metadataPrefix available.
	Therefore, this module cannot test well for the cannotDisseminateFormat
	error (if the value of the metadataPrefix argument is not supported by
	the repository).

=head1 	TODO

	It should be possible to set a list of globally supported formats, assuming
	that each record in your repository is always supported in all formats
	which your repository supports. If this is not the case implement your
	own cannotDisseminateFormat check.

	HTTP::OAI::HeaderCache::SupportedMetadataFormats=qw/ dc_oai example_prefix/;

	###TODO: I do wonder if I preserve the resumptionTokens the way filter here

=head1 SUBROUTINES/METHODS

=head2 new HTTP::OAI::DataProvider::Simple::HeaderCache (ns_prefix=>'oai_dc',
	   ns_uri=>'http://example.org')

This constructor returns the HTTP::OAI::HeaderCache object. On failure return
nothing.

New parameters allow to describe namespace of native (internal) format. This
refers to the namespace of the xml which will be read. You need to set this
only if you want to read xml and create a new header.

=cut

sub new {
	my $self  = {};
	my $class = shift;

	my %args = @_;    #ns_uri and ns_prefix are optional

	#cp only ns_uri and ns_prefix to $self
	if ( $args{'ns_uri'} ) {
		$self->{ns_uri} = $args{ns_uri};
	}
	if ( $args{ns_prefix} ) {
		$self->{ns_prefix} = $args{ns_prefix};
	}

	bless( $self, $class );
	return $self;

	#if you ever add any parameters here make sure you add them to
	#_query as well
}

=head2 my $error=$cache->import_single (source=>$xml_fn, mapping=>&mapping);

Loads an xml source file and hands it over to the mapping (callback). On
success returns 1; on failure nothing.

Error handling:
my $error=$cache->import_single (location=>$xml_fn, mapping=>&mapping);
if ($error) {
	#do something
}

=cut

sub import_single {
	my $self = shift;    #this is cache
	my %args = @_;

	if ( !-e $args{source} ) {
		croak 'import_single cannot find source xml at (' . $args{source} . ')';
	}

	#$args->mapping not yet implemented?

	#print "source:".$args{source_xml}."\n";
	my $doc = $self->_loadXML( $args{location} );

	#now we have $doc, let's call the mapping

	my @headers;
	if ( !$args{mapping} ) {
		carp "No mapping callback specified, I use default mapping";
		@headers = extractHeaderFromSource($doc);
	} else {

		@headers = &{ $args{mapping} }($doc);
	}
	if ( @headers == 0 ) {

		#if still no headers something is like to have gone wrong,
		#but could be just empty soruce doc return ();

		carp "Warning: Still no headers after mapping the source document!";
	}

	my $LI = new HTTP::OAI::ListIdentifiers;
	foreach (@headers) {
		$LI->identifier($_);
	}
	$self->{'ListIdentifiers'} = $LI;    #wrap LI in object
	return 1;                            #on success
	return ();                           #on error
}

sub _registerNS {
	my $self = shift;
	my $doc  = shift;
	if ( $self->{ns_prefix} ) {
		if ( !$self->{ns_uri} ) {
			croak "ns_prefix specified, but ns_uri missing";
		}
		$doc = XML::LibXML::XPathContext->new($doc);
		$doc->registerNs( $self->{ns_prefix}, $self->{ns_uri} );
	}
	return $doc;
}

#my $doc=$cache->_loadXML ($file);
sub _loadXML {
	my $self     = shift;
	my $location = shift;

	if ( !$location ) {
		croak "Nothing to load";
	}

	my $doc = XML::LibXML->load_xml( location => $location )
	  or croak "Could not load " . $location;

	$doc = _registerNS( $self, $doc );

	if ( !$doc ) {
		croak "Warning: somethings strange with $location of them";
	}
	return $doc;
}

=head2 import_dir

like import_single, but for directories: Loads all files in a given directory
and hands it over to the mapping (callback). On success returns 1. On failure
nothing.

Currently this method expects every file to be an xml file, no matter what the
actual file extension or the actual content of the file.

=cut

sub import_dir {
	my $self = shift;    #this is cache
	my %args = @_;

	if ( !$args{location} ) {
		croak 'import_dir: no location specified';
	}

	if ( !-d $args{location} ) {
		croak 'import_dir cannot find source dir at (' . $args{location} . ')';
	}

	if ( !$args{mapping} ) {
		carp "No mapping callback specified, I use default mapping";
	}

	my @headers;
	opendir( my $dh, $args{location} )
	  or croak "Can't opendir $args{location}: $!";
	carp "dir: $args{location}";
	foreach ( readdir $dh ) {
		my $file = $args{location} . "/$_";
		if ( -f $file ) {
			carp "file:$file";
			my $doc = $self->_loadXML($file);

			if ( !$args{mapping} ) {
				push @headers, extractHeaderFromSource($doc);
			} else {
				@headers = &{ $args{mapping} }($doc);
			}
		}
	}
	closedir $dh;

	#more error checking and preparation for return
	if ( @headers == 0 ) {
		carp "Warning: Still no headers after mapping the source document!";
	}

	my $LI = new HTTP::OAI::ListIdentifiers;

	#now we have $doc, let's call the mapping
	foreach (@headers) {
		$LI->identifier($_);
	}
	$self->{'ListIdentifiers'} = $LI; #wrap LI in object
	                                  #return magic 1 on success, on error? TODO
}

=head2 extractHeaderFromSource ($doc)

my @headers=extractHeaderFromSource ($doc);

This is an example mapping which extracts headers from a source document.
Implement your own method if you want to. It gets a LibXML document (or xpath)
as in input and outputs an array of HTTP::OAI::Headers.

You could implement rules which decide on sets if you like.

PS: It might be that this mapping is called from both import_single and
import_dir.

TODO: This has to go out of HeaderCache. It has to be part of the
implementation Salsa OAI.

=cut

sub extractHeaderFromSource {
	my $doc = shift;
	my @result;

	croak "Error: No doc" if !$doc;

	my @nodes = $doc->findnodes('/mpx:museumPlusExport/mpx:sammlungsobjekt');

	foreach my $node (@nodes) {
		my @objIds      = $node->findnodes('@objId');
		my $id_orig     = $objIds[0]->value;
		my $id_oai      = 'spk-berlin.de:EM-objId-' . $id_orig;
		my @exportdatum = $node->findnodes('@exportdatum');
		my $exportdatum = $exportdatum[0]->value . 'Z';

		print "\t$id_oai--$exportdatum\n";
		my $header = new HTTP::OAI::Header(
			identifier => $id_oai,
			datestamp  => $exportdatum,

			#TODO:status=> 'deleted', #deleted or none;
		);

		$node = XML::LibXML::XPathContext->new($node);
		$node->registerNs( 'mpx', 'http://' );

		#$node=_registerNS ($self,$node);

		#example of mapping set to simple mpx criteria
		my $objekttyp = $node->findvalue('mpx:objekttyp');
		print "\tobjekttyp: $objekttyp\n";
		if ( $objekttyp eq 'Musikinstrument' ) {
			$header->setSpec('MIMO');
		}

		push @result, $header;
	}
	return @result;
}

=head2 $cache->mkHeader($dom);

DEPRECATED

use the information from dom to write headers. This function should not be
on module level. TODO:use callback instead.

=cut

sub mkHeader {
	my $self = shift;
	my $doc  = shift;    #dom

	croak "Error: No doc" if !$doc;

	my $LI    = new HTTP::OAI::ListIdentifiers;
	my @nodes = $doc->findnodes('/mpx:museumPlusExport/mpx:sammlungsobjekt');

	foreach my $node (@nodes) {
		my @objIds      = $node->findnodes('@objId');
		my $id_orig     = $objIds[0]->value;
		my $id_oai      = 'spk-berlin.de:EM-objId-' . $id_orig;
		my @exportdatum = $node->findnodes('@exportdatum');
		my $exportdatum = $exportdatum[0]->value . 'Z';

		print "\t$id_oai--$exportdatum\n";
		my $header = new HTTP::OAI::Header(
			identifier => $id_oai,
			datestamp  => $exportdatum,

			#TODO:status=> 'deleted', #deleted or none;
		);

		#TODO:
		$header->setSpec('test');
		$LI->identifier($header);

	}
	$self->{'ListIdentifiers'} = $LI;    #wrap LI in object
}

=head2 write_cache($target_fn);

Write cache to disk. Overwrites (updates) files without warning.

TODO:On failure?

=cut

sub write_cache {
	my $self   = shift;
	my $target = shift;
	my $cache  = $self->{ListIdentifiers};

	#overwrite files without warning
	if ( $target =~ /.xml$/ ) {

		#write in xml for fun and debugging only
		#TODO:verbose "About to write XML output\n";
		open( my $fh, '>:encoding(UTF-8)', $target )
		  or die "Cannot write to $target";
		print $fh $cache->toDOM->toString;
		close($fh);
	} else {

		#write to yaml to speed things up
		#verbose "About to write YAML output\n";
		open( my $fh, '>', $target )
		  or die "Cannot write to $target";
		print $fh Dump ($cache);
		close($fh);
	}
}

=head2 HTTP::OAI::HeaderCache::load_cache($yaml_cache_fn);

This is a NOT constructor ANYMORE, alternative to new. Expects a yaml file with
a HTTP::OAI::ListIdentifier object which in turn has all headers you want to
query. (You likely want to write such a file with write, see above.)
On failure return nothing.

TODO: return proper HTTP::OAI::HeaderCache Error

=cut

sub load_cache {

	my $class    = shift;
	my $cache_fn = shift;
	my $self     = {};      #make a new class
	                        #yaml file expected
	$class->{ListIdentifiers} = LoadFile($cache_fn)
	  or die "Cannot load cache ($cache_fn)";
}

=head2 my @headers=$cache->loop

Returns a list of headers. Resets the loop to the beginning. Might be bad
performance. Can be used to count the headers:

  print 'Head count'.$cache->loop."\n";

Returns 0 if no header left, but doesn't raise the error.

=cut

sub loop {
	my $self = shift;
	my @headers;

	#
	#TODO: could be that I have to set loop back at some point
	#

	my $LI = $self->{ListIdentifiers};
	if ($LI) {
		my $LI_new = new HTTP::OAI::ListIdentifiers;
		while ( my $h = $LI->next ) {
			push @headers, $h;
			$LI_new->identifier($h);
		}

		#return list to original state
		$self->{ListIdentifiers} = $LI_new;
		return @headers;
	}
	return 0;
}

=head2 my $header=$cache->toListIdentifiers

Returns the list of headers. If you change that list, it'll change the $cache.
It should probably return a clone of that list (TODO).

=cut

sub toListIdentifiers {
	my $self = shift;

	if ( $self->{ListIdentifiers} ) {
		return $self->{ListIdentifiers};
	}
}

=head2 $cache->checkRecordsMatch

Throws an noRecordsMatch error if cache has no header left. No return value,
just modifies the cache object that it is passed.

=cut

sub checkRecordsMatch {
	my $self  = shift;
	my @count = $self->loop;
	if ( @count < 1 ) {
		push @{ $self->{errors} },
		  new HTTP::OAI::Error( code => 'noRecordsMatch' );
		return ();    #fail
	}
	return 1;         #pass
}

=head2 checkUntil ($header,\%arg);

This is a method not a function. How cool is that!? Returns true if $arg{until}
is either not defined or header's timestamp is younger than the unitl value.

=cut

sub checkUntil {
	my ( $header, %arg ) = @_;

	if ( !$arg{until} ) {

		#if no until specified, I want every record
		return 1;
	}

	if ( $header->datestamp ) {
		if ( $header->datestamp lt $arg{until} ) {
			return 1;    #success. Let's keep this header
		}    #false when no datestamp. why is there no ds?
	}
}

=head2 checkSet ($header,\%arg);

Returns true if no set defined or if set from header matches one of the sets in
the query.

=cut

sub checkSet {
	my ( $header, %arg ) = @_;
	if ( !$arg{set} ) {
		return 1;    #if no set in query: true
	}

	my @sets = $header->setSpec;
	if (@sets) {
		if ( grep ( $arg{set} eq $_, @sets ) ) {
			return 1;    #a header set matches query set

		}
		return ();       #sets exist, but dont match
	}

	#no set in header: false (at this point)
	return ();
}

=head2 checkFrom ($header,\%arg);

Returns true if $arg{from} is either not defined or the header's timestamp is
younger than the from value. This is a method not a function. How cool is
that!?

=cut

#This is a method not a function
sub checkFrom {
	my ( $header, %arg ) = @_;

	if ( !$arg{from} ) {

		#if no from specified, I want every record
		return 1;
	}

	if ( $header->datestamp ) {
		if ( $header->datestamp gt $arg{from} ) {
			return 1;    #success. Let's keep this header
		}
	} else {

		#WHY should there not be a datestamp? Indicates a corrupt header
		die "Corrupt headerCache?";
	}    # false when no no datestamp?
}

=head2 $result=$cache->_query (metadatPrefix=>'x', until=>'xy', from=>'xz',set=>'x');

This is the new "filter" method. Only one loop. Returns a new cache obj which
contains only those headers compling with all criteria (AND). Throws an error
if no metadataPrefix specified, but doesn't process it otherwise. Returns
HTTP::OAI::Error Objects in an array of the result:

$result=$cache->_query (metadatPrefix=>'x', until=>'xy');
if ($result->isError) {
	print $result->err2str;
}

=cut

sub _query {
	my ( $result, $cache, %arg ) = @_;

	#print "DEBUG Enter _query\n";
	#print "header count (result):".$result->loop."\n";
	#$arg{set}, $arg{from}, $arg{until}
	#I do NOT manipulate $self whatsoever

	my $LI = new HTTP::OAI::ListIdentifiers;

	#TODO: Split sets and deal with set hierarchy!

	if ( $cache->{'ListIdentifiers'} ) {

		#this while consumes all its items like a mother who eats her children
		#therefore I collect the children and put them back into the LI
		my $LI_new = new HTTP::OAI::ListIdentifiers;
		while ( my $header = $cache->{'ListIdentifiers'}->next ) {
			$LI_new->identifier($header);

			#does any of the sets in this header match the query's header?
			if ( checkSet( $header, %arg ) ) {

				#print "pass checkSet: " . $header->identifier . "\n";
				if ( checkUntil( $header, %arg ) ) {

					#print "pass checkUntil:" . $header->identifier . "\n";
					if ( checkFrom( $header, %arg ) ) {

						#print "pass checkFrom:" . $header->identifier . "\n";
						$LI->identifier($header);
					}
				}
			}
		}

		#return list to original state. Prevent mom from eating her children
		$cache->{ListIdentifiers} = $LI_new;
	}

	#overwrite LI in cache obj
	$result->{'ListIdentifiers'} = $LI;

	#print "header count (AFER):".$cache->loop."\n";
	if ( $cache->{ns_uri} ) {
		$result->{ns_uri} = $cache->{ns_uri};
	}
	if ( $cache->{ns_prefix} ) {
		$result->{ns_prefix} = $cache->{ns_prefix};
	}

	#print "header count (result):".$result->loop."\n";

	#dont need to return result anymore
	#return $result;
}

=head2 my $result=$cache->query(from, until, set, metadaPrefix);

TODO: Usage: my $result=$cache->query(resumptionToken);

Returns only headers which comply with query. On failure returns a HTTP::OAI::
HeaderCache with error message(s) inside.

The new version does not shrink the cache. It leaves it untouched and returns
a "clone" of the cache which only contains results of the query.

=cut

sub query {
	my ( $self, %arg ) = @_;
	my $result = new HTTP::OAI::DataProvider::Simple::HeaderCache();

	#print "DEBUG: enter query\n";
	#print "header count:".$self->loop."\n";

	#TODO
	if ( $arg{resumptionToken} ) {
		push(
			@{ $result->{errors} },
			new HTTP::OAI::Error(
				code    => 'badResumptionToken',
				message => 'Todo: currently resumption is not supported'
			)
		);
	}

	#test if prefix supported is done elsewhere
	#i should not have to test if mdp is missing here either, but why not?
	if ( !$arg{metadataPrefix} ) {
		croak "metadataPrefix missing!";
	}

	#It's a bit unexpected that if validation succeeds when it fails, but who
	#cares really?
	foreach (qw/until from/) {
		if ( $arg{$_} ) {
			if ( validate_date $arg{$_} ) {
				push(
					@{ $result->{errors} },
					return new HTTP::OAI::Error(
						code    => 'badArgument',
						message => "Argument $_ is not a valid date"
					)
				);
			}
		}
	}

	#the actual query, not tests
	#modify result
	$result->_query( $self, %arg );

   #print "header count (result, after return from _query):".$result->loop."\n";

	#check if any result headers at all
	$result->checkRecordsMatch;

	#print "header count (before return):".$result->loop."\n";
	#print "header count (result, at the end of query):".$result->loop."\n";
	return $result;
}

=head2 @sets=$cache->listSets

Returns a list with the setSpecs (as strings) in the cache. To do loop
the method loops once through the cache. (Returns them in alphabetical
order since time for ListSets seems not crucial.)

=cut

sub listSets {
	my $self = shift;

	my %encountered;
	my @count = $self->loop;

	#print "count headers in cache:" . @count . "\n";
	foreach my $header (@count) {

		#each header can have multiple sets
		if ( $header->setSpec ) {
			foreach my $setSpec ( $header->setSpec ) {

				#print "CC: setSpec:$setSpec\n";
				$encountered{$setSpec} = 0;
			}
		}
	}
	my @sets;

	#for speed could also use cmp to sort
	foreach my $setSpec ( sort keys %encountered ) {

		#debug "encountered set $setSpec $setsEncountered{$setSpec} times";
		push( @sets, $setSpec );
	}

	return @sets;
}

=head2 $str=$cache->toXML;

Just return the whole (or remaining) cache as XML, handy for ListIdentifiers.
Does not do any XSLT buisness because headerCache does not know about it
(settings).

=cut

#This is the version which acts on this class
sub toXML {
	my $class = shift or die "nothing here";
	return $class->{ListIdentifiers}->toDOM->toString;
}

=head2 my $str=$cache->err2str;
	Turn errors in cache to string (for debugging);
=cut

sub err2str {
	my $self = shift;
	my $str;

	if ( @{ $self->{errors} } ) {
		$str .= "Errors:\n";
		foreach ( @{ $self->{errors} } ) {
			if ( $_->code ) {
				$str .= ' ' . $_->code . "\n";
			}
			if ( $_->message ) {
				$str .= '  ' . $_->message . "\n";
			}
		}
		return $str;
	}
}

=head2 errorsToXML
#turn error objects into xml string
#expects a list of errors (HTTP::OAI::Error)
#return xml as string

new name could be err2XML

=cut

sub errorsToXML {
	my $self     = shift;
	my $response = new HTTP::OAI::Response;
	my $xml;
	if ( @{ $self->{errors} } ) {
		my @errors;
		foreach ( @{ $self->{errors} } ) {
			$response->errors($_);
			push @errors, $response;
		}
		return $response->toDOM->toString;
	}
}

=head2	$header=$cache->findByIdentifier($identifier)
	Finds and return a specific header (HTTP::OAI::Header) by identifier.
	If none found returns nothing.

=cut

sub findByIdentifier {
	my $self       = shift;
	my $identifier = shift;

	foreach my $header ( $self->loop ) {

		#print 'dfd'.$header->identifier."\n";
		if ( $identifier eq $header->identifier ) {
			return $header;
		}
	}

	#carp "header NOT found";
	return;
}

=head2 isError
	if ($cache->isError){
		#do in case of error
	}
	#return usually contains HTTP::OAI::Error, but not always
	my @return=$cache->isError

=cut

sub isError {
	my $self = shift;
	if ( exists $self->{errors} ) {
		return @{ $self->{errors} };
	}
	return ();
}

1;    #perldancer_is_cool; # End of HTTP::OAI::HeaderCache

=head1 SEE ALSO

Tim Brody's HTTP::OAI on CPAN

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-http-oai-headercache at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTTP-OAI-HeaderCache>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HTTP::OAI::HeaderCache


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HTTP-OAI-HeaderCache>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HTTP-OAI-HeaderCache>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HTTP-OAI-HeaderCache>

=item * Search CPAN

L<http://search.cpan.org/dist/HTTP-OAI-HeaderCache/>

=back

=head1 ACKNOWLEDGEMENTS

With support from MIMO, http://mimo-project.eu

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut