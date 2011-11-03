#!/usr/bin/perl
$options = {};
$options = {
	adminEmail        => 'mauricemengel@gmail.com',
	baseURL           => 'http://localhost:3000/oai',
	chunkCacheMaxSize => 4000,
	chunkSize         => 10,

	#dbfile value for test is not good...
	dbfile        => "$FindBin::Bin/db",
	deletedRecord => 'transient',

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
	locateXSL      => 'Salsa_OAI::MPX::locateXSL',
	nativePrefix   => 'mpx',
	repositoryName => 'test config OAI Data Provider',
};
