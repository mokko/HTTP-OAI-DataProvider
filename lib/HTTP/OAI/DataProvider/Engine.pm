package HTTP::OAI::DataProvider::Result;

=head2 Engine Requirements

Engine interfaces the data store on the one side and data provider on the side.

What does the engine need?

	my $header=findByIdentifier ($identifier);
	my $date=$engine->earliestDate();
	my $granuality=$engine->granularity();
	my @used_sets=$engine->listSets();

	my $result=$engine->queryHeaders ($params);
	my $result=$engine->queryRecords ($params);

=cut

=head2 my $cache=new HTTP::OAI::DataRepository::Result (
);
=cut

sub new {
	my $class = shift;
	my $self  = _new $class;

	if ( !@_ ) {
		croak "Internal Error: Parameters missing";
	}

	my %args = @_;

	if ( !$self ) {
		croak "Internal error: Cannot create myself";
	}

	#Debug "Enter HTTP::OAI::DataProvider::SQLite::_new";

	if ( !$args{dbfile} ) {
		carp "Error: need dbfile";
	}

	if ( $args{ns_uri} ) {
		Debug "ns_uri" . $args{ns_uri};
		$self->{ns_uri} = $args{ns_uri};
	}

	if ( $args{ns_prefix} ) {
		Debug "ns_prefix" . $args{ns_prefix};
		$self->{ns_prefix} = $args{ns_prefix};
	}

	#i could check if directory in $dbfile exists; if not provide
	#intelligble warning that path is strange

	_connect_db( $args{dbfile} );
	_init_db();

	#I cannot test earlierstDate since non existant in new db
	#$self->earliestDate();    #just to see if this creates an error;

	return $self;
}



#to inherit

#adds an error to a result object
# $self->_addError($code[, $message]);
sub _addError {
	my $self = shift;
	my $code = shift;    #required
	my $msg  = shift;    #optional

	if ( !$code ) {
		die "_addError needs a code";
	}

	my %arg;
	$arg{code} = $code;

	if ($msg) {
		$arg{message} = $msg;
	}

	if ($code) {
		push( @{ $self->{errors} }, new HTTP::OAI::Error(%arg) );
	}
}



#my $doc=$cache->_loadXML ($file);
sub loadXML {
	my $self     = shift;
	my $location = shift;

	Debug "Enter _loadXML ($location)";

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


1; #HTTP::OAI::DataProvider::Engine
