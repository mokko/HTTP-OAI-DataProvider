#options for testing the data provider
%config = (
	identify => {
		adminEmail     => 'mauricemengel@gmail.com',
		baseURL        => 'http://localhost:3000/oai',
		deletedRecord  => 'transient',
		repositoryName => 'test config OAI Data Provider',
	},

	engine => {
		chunkCache => {
			maxChunks       => 4000,    #was chunkCacheMaxSize
			recordsPerChunk => 10,      #was chunkSize
		},
		dbfile    => "$FindBin::Bin/../t/environment/db",
		engine    => 'HTTP::OAI::DataProvider::Engine::SQLite',
		locateXSL => sub {
			my $prefix       = shift;
			my $nativePrefix = ( keys %{ $config{engine}{nativeFormat} } )[0]
			  or die "nativePrefix missing";
			return "$FindBin::Bin/../t/environment/$nativePrefix" . '2'
			  . "$prefix.xsl";
		},
		nativeFormat => { 'mpx' => 'http://www.mpx.org/mpx' }
	},
	messages => {
		debug   => sub { my $msg = shift; print "<<$msg\n" if $msg; },
		warning => sub { my $msg = shift; warn ">>$msg"    if $msg; },
	},

	globalFormats => {
		mpx => {
			ns_uri => "http://www.mpx.org/mpx",
			ns_schema =>
			  "http://github.com/mokko/MPX/raw/master/xsd/mpx.xsd",
		},
		oai_dc => {
			ns_uri    => "http://www.openarchives.org/OAI/2.0/oai_dc/",
			ns_schema => "http://www.openarchives.org/OAI/2.0/oai_dc.xsd",
		},
	},
	#requestURL => 'http://testurl.com',
	setLibrary => {
		'78' => {
			    'setName' => 'Schellackplatten aus dem Phonogramm-Archiv'
			  . ' (ursprünglich für DISMARC exportiert)'
		},
		'MIMO' =>
		  { 'setName' => 'Musical Instruments selected for MIMO project' },
		'test' => {
			'setName' => 'testing setSpecs - might not work without this one',

	  #   			'setDescription'=>'<oai_dc:dc
	  #         xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	  #          xmlns:dc="http://purl.org/dc/elements/1.1/"
	  #          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	  #          xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/
	  #          http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
	  #          <dc:description>This set contains metadata describing
	  #             electronic music recordings made during the 1950ies
	  #             </dc:description>
	  #       </oai_dc:dc>'
		},
	},
	xslt => '/oai2.xsl',
);
