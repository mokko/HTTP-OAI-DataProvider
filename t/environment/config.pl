#options for testing the data provider
%config = (
	#required
	adminEmail        => 'mauricemengel@gmail.com',
	baseURL           => 'http://localhost:3000/oai',
	deletedRecord => 'transient',

	#not required at the moment, but should be
	chunkCacheMaxSize => 4000,
	chunkSize         => 10,

	#dbfile value for test is not good...
	dbfile        => "$FindBin::Bin/../t/environment/db",
	debug => sub { my $msg = shift; print "<<$msg\n" if $msg; },

	#capital letter important: GlobalFormats
	GlobalFormats => {
		mpx => {
			ns_uri    => "http://www.mpx.org/mpx",
			ns_schema =>
			  "http://github.com/mokko/MPX/raw/master/latest/mpx.xsd",
		},
		oai_dc => {
			ns_uri    => "http://www.openarchives.org/OAI/2.0/oai_dc/",
			ns_schema => "http://www.openarchives.org/OAI/2.0/oai_dc.xsd",
		},
	},
	locateXSL      => sub  {
		my $prefix       = shift;
		my $nativeFormat = $config{nativePrefix} or die "Info on nativeFormat missing";
		return "$FindBin::Bin/../t/environment/$nativeFormat".'2'."$prefix.xsl";
	},
	nativePrefix   => 'mpx',
	native_ns_uri=> 'http://www.mpx.org/mpx',
	repositoryName => 'test config OAI Data Provider',
	setLibrary=>{
		'78' => {
			'setName'=> 'Schellackplatten aus dem Phonogramm-Archiv (ursprünglich für DISMARC exportiert)' 
		},
 		'MIMO'=> {
   			'setName'=> 'Musical Instruments selected for MIMO project' 
   		},
  		'test' => {
   			'setName'=> 'testing setSpecs - might not work without this one',
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
	warning => sub { my $msg = shift; warn ">>$msg" if $msg; },
	xslt=>'/oai2.xsl',
);