package HTTP::OAI::DataProvider::Test;
{
  $HTTP::OAI::DataProvider::Test::VERSION = '0.007';
}
# ABSTRACT: Testing the data provider
use strict;
use warnings;
use Test::More;
use Test::Xpath;
use FindBin;
use XML::LibXML;
use Carp qw(carp croak);

#use Scalar::Util;
use HTTP::OAI::DataProvider::Common qw(
  isScalar
  testEnvironment
  valPackageName
);
use HTTP::OAI::DataProvider::Valid;
use base 'Exporter';
our @EXPORT_OK;
our @EXPORT;

#verb tests, OAI error tests, utilities
@EXPORT = qw (
  okIdentify
  okGetRecord
  okListIdentifiers
  okListMetadataFormats
  okListRecords
  okListSets

  isLMFprefix

  isOAIerror
  oaiErrorResponse

  failOnRequestError

  loadWorkingTestConfig
  testEnvironment
  testSequence
  xpathTester
);

#old stuff deprecated? Should be removed?
@EXPORT_OK = qw(
  okIfIdentifierExists

  okOaiResponse
  okValidateOAIgone
  okValidateOAILaxgone

  isOAIerror
  isMetadataFormat
  isSetSpec

  oaiError
);


sub okGetRecord {
	my $response = shift or croak "Need xml as string!";
	_okType( $response, 'GetRecord', shift );
}

sub okIdentify {
	my $response = shift or croak "Need xml as string!";
	_okType( $response, 'Identify', shift );
}

sub okListIdentifiers {
	my $response = shift or croak "Need xml as string!";
	_okType( $response, 'ListIdentifiers', shift );
}

sub okListRecords {
	my $response = shift or croak "Need xml as string!";
	_okType( $response, 'ListRecords', shift );
}

sub okListMetadataFormats {
	my $response = shift or croak "Need xml as string!";
	_okType( $response, 'ListMetadataFormats', shift );
}

sub okListSets {
	my $response = shift or croak "Need xml as string!";
	_okType( $response, 'ListSets', shift );
}

#generic for okIfListIdentifiers,okIfIdentify etc.
sub _okType {
	my $response = shift or croak "Need xml as string!";
	my $type     = shift or croak "Need type!";
	my $msg = shift || "response validates and is of type $type\n";
	isScalar($response);
	my @validVerbs = qw(Identify GetRecord ListIdentifiers ListMetadataFormats
	  ListRecords ListSets);

	if ( !grep ( $_ eq $type, @validVerbs ) ) {
		croak "Error: Unknown type ($type)!";
	}

	my $xpath = "/oai:OAI-PMH/oai:$type";
	my $lax = ( $type =~ /^ListRecords$|^GetRecord$/ ) ? 'lax' : '';

	#print "LAX:$lax|type:$type\n";
	if ( !_validateOAIresponse( $response, $lax ) ) {
		fail "$type response does not validate $lax";
	}

	_failIfOAIerror( _response2dom($response) );

	my $xt = xpathTester($response);

	#print $response."\n";
	$xt->ok( $xpath, $msg );

}


sub isLMFprefix {
	my $response = shift or croak "Need response";
	my $prefix   = shift or croak "Need prefix";
	isScalar($prefix);
	my $dom = _response2dom($response);

#print "ENTER isLMFprefix:$response\n";
#If I assume that type has already been tested, I don't need to repeat any of these as well
#_failValidationError($dom);
#_failIfOAIerror($dom);
#_failIfNotType ($dom,'type');

	my $xt    = xpathTester($response);
	my $xpath = q(/oai:OAI-PMH/oai:ListMetadataFormats/oai:metadataFormat)
	  . qq([oai:metadataPrefix ='$prefix']);

	#print "XPATH:$xpath\n";
	$xt->ok( $xpath, "response has metadataPrefix='$prefix'" );
}


sub isOAIerror {
	my $response = shift or croak "Need response!";
	my $code     = shift or croak "Need error type to look for!";
	isScalar($response);
	isScalar($code);
	
	my @errors = qw (
	  badArgument
	  badResumptionToken
	  cannotDisseminateFormat
	  idDoesNotExist
	  noMetadataFormats
	  noRecordsMatch
	  noSetHierarchy);

	if ( !grep ( $_ eq $code, @errors ) ) {
		print "Unrecognized OAI error code ($code)\n";
	}

	my $dom = _response2dom($response);
	_failValidationError($dom);
	my $oaiError = _failNoOAIerror($dom);

	ok( defined $oaiError->{$code}, "expect OAIerror of type '$code'" );
}


sub _okIfBadArgument {
	my $response = shift or croak "Error: Need response!";
	isOAIerror( $response, 'badArgument' );
}


sub loadWorkingTestConfig {
	my $signal   = shift; #optional

	my $fileName = HTTP::OAI::DataProvider::Common::testEnvironment('config');

	if ( !-e $fileName ) {
		carp "working test config not found!";
	}

	my %config = do $fileName or return;

	#in lieu of proper validation
	#croak "Error: Not a hashref" if ref $config ne 'HASH';

	#signal in first level?
	if ( $signal && $config{$signal} ) {
		return %{$config{$signal}};
	}

	#signal in 2nd level?
	if ( $signal) {
		foreach my $first (keys %config) {
			if ($config{$first}{$signal}) {
				return %{$config{$first}{$signal}};				
			}
		}
	#return complete hash	
	return %{$config{$signal}};
	}
	
	return %config;
}



sub oaiErrorResponse {
	my $response = shift or croak "Need response!";
	isScalar($response);
	my $dom = _response2dom($response);
	return oaiError($dom);
}


sub oaiError {
	my $doc = shift or croak "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $xc    = _registerOAI($doc);
	my $error = {};

	#todo: this should be foreach to check for multiple errors
	if ( $xc->exists('/oai:OAI-PMH/oai:error') ) {
		my $code = $xc->findvalue('/oai:OAI-PMH/oai:error/@code');
		my $desc = '';
		$desc = $xc->findvalue('/oai:OAI-PMH/oai:error');

		#print "badewanne".$doc->toString."\n";
		if ($code) {
			$error->{$code} = $desc;
			return $error; #success, i.e. error exists
		}
	}
	return; #failure,i.e. no error
}


sub failOnRequestError {
	if ( my @e = HTTP::OAI::Repository::validate_request(@_) ) {
		fail "Query error: " . grep ( $_->code, @e ) . "\n";
		exit 1;
	}
}



sub testSequence {
	my %opts = @_;
	my @sequence = @{ $opts{sequence} };
	my $provider = new HTTP::OAI::DataProvider( %{ $opts{config} } );

	foreach my $params (@sequence) {
		my $verb = $params->{verb};
		delete( $params->{verb} );

		$opts{codeRef}( $provider, $verb, $params );
	}
}




sub xpathTester {
	my $response = shift or croak "Need response!";
	isScalar $response;
	return Test::XPath->new(
		xml   => $response,
		xmlns => { oai => 'http://www.openarchives.org/OAI/2.0/' },
	);
}


sub _failNoOAIerror {
	my $dom = shift or croak "Need dom!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $oaiError = oaiError($dom);
	if ( !$oaiError ) {
		fail 'No error where OAI error expected!';
		exit 1;
	}
	return $oaiError;
}

sub _failIfOAIerror {
	my $dom = shift or croak "Need dom!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $oaiError = oaiError($dom);
	if ($oaiError) {
		my @e = keys %{$oaiError};
		fail "Error:Unexpected OAI error (@e)!";
		exit 1;
	}
}

sub _failValidationError {
	my $dom = shift or croak "Need dom!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $v   = new HTTP::OAI::DataProvider::Valid;
	my $err = $v->validate($dom);
	if ( $err ne 'ok' ) {
		fail "Response not valid!";
		exit 1;
	}
}


sub _response2dom {
	my $response = shift or croak "Error: Need response!";
	isScalar($response);    #croaks if not scalar

	return XML::LibXML->load_xml( string => $response );
}


sub _registerOAI {
	my $dom = shift or croak "Error: Need doc!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $xc = XML::LibXML::XPathContext->new($dom);
	$xc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );
	return $xc;
}


sub _validateOAIresponse {
	my $response = shift or croak "Error: Need doc!";
	my $type = shift || '';

	#print "TYPE:$type\n";
	my $doc = XML::LibXML->load_xml( string => $response );
	my $v = new HTTP::OAI::DataProvider::Valid;

	my $msg;
	if ( $type eq 'lax' ) {
		$msg = $v->validateLax($doc);
	}
	else {
		$msg = $v->validate($doc);
	}

	#print "msg:$msg (type:$type)\n";
	if ( $msg eq 'ok' ) {
		return 1;    #success
	}
	carp "$msg\n";
	return 0;
}

###
###
###


sub okIfListRecordsMetadataExists {
	my $doc = shift or croak "Error: Need doc!";
	okIfXpathExists(
		$doc,
		'/oai:OAI-PMH/oai:ListRecords/oai:record[1]/oai:metadata',
		'first record has metadata'
	);
}


sub _okIfXpathExists {
	my $doc = shift or croak "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $xpath = shift or croak "Error: Need xpath!";

	#TODO validate xpath

	my $msg = shift || '';

	my $xc    = _registerOAI($doc);
	my $value = $xc->findvalue($xpath);

	ok( $value, $msg );
}


sub isMetadataFormat {
	my $response = shift or croak "Need response!";
	my $prefix   = shift or croak "Need prefix!";
	my $msg = shift || '';    #optional
	isScalar($response);
	isScalar($prefix);
	isScalar($msg);

	my $xpath = '/oai:OAI-PMH/oai:ListMetadataFormats/oai:metadataFormat/'
	  . "oai:metadataPrefix[. = $prefix]";

	my $xt = xpathTester($response);
	$xt->ok( $xpath, $prefix, $msg );
}


sub isSetSpec {
	my $response = shift or croak "Need response!";
	my $setSpec  = shift or croak "Need setSpec!";
	isScalar($response);
	isScalar($setSpec);
	my $msg   = "setSpec '$setSpec' exists";
	my $xpath = "/oai:OAI-PMH/oai:ListSets/oai:set[oai:setSpec = $setSpec]";

	my $xt = xpathTester($response);
	$xt->is( $xpath, $setSpec, $msg );
}


sub _okOaiResponse {
	my $doc = shift or croak "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $err = oaiError($doc);
	if ($err) {
		print "   OAI-Error:\n";
		foreach my $code ( keys %{$err} ) {
			print "   $code->" . $err->{$code} . "\n";
		}
	}
	ok( !defined $err, 'OAI response error free' );
}


1;

__END__
=pod

=head1 NAME

HTTP::OAI::DataProvider::Test - Testing the data provider

=head1 VERSION

version 0.007

=head1 FUNCTIONS

=head2 okGetRecord($response[,'optional alternative msg']);
=func okIdentify($response[,'optional alternative msg']);
=func okListIdentifiers($response[,'optional alternative msg']);

=head2 okListRecords($response[,'optional alternative msg']);
=func okListMetadataFormats($response[,'optional alternative msg']);
=func okListSets($response[,'optional alternative msg']);

New version of tests. Validates and checks if element named after verb (aka 
'the type') exists.

=head2 isLMFprefix ($response, 'prefix');

test if ListMetadataFormats response contains a specific prefix.

=head3 OAI Error tests

=head2 isOAIerror ($response, $code);

passes if $response is of error type $code

=head2 okIfBadArgument ($response);

passes if response is OAI error badArgument.

DEPRECATED! 
Instead use: 
	C<isOAIerror ($response, 'badArgument');>

=head2 my %config =
	  HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

	loadWorkingTestConfig returns a hashref with a working configuration .

=head2 my $err=oaiErrorResponse ($response)

=head2 $hashref=oaiError($oai_response_as_dom);

Most of the time you want oaiErrorResponse instead of this one. Still trying to
figure out if this function should be internal.

Returns nothing if no response is not an error. If the response is erroneous, 
returns a hashref with one or more errors.

	$hashref->{code}->{description};

test for error with:
	if (my $err=oaiError $dom) {
		foreach my $code (keys %{$err}){
			print "code:$code->".$err->{$code}."\n";
		}
	}

=head2 failOnRequestError(%params);

Expects the parameters you are about to hand over to data provider as a hash.
Fails with meaninggful error message and exists if the parameters are not 
valid. (Wrapper around HTTP::OAI::Repository::validate_request.)

=head2 my $xt=xpathTester($response);

returns an Test::XPath object, so you can do things like:
	$xt->ok($xpath, 'msg');

See L<Test::XPath> for details

=head2 my $dom=_response2dom ($response);

expects a xml as string. Returns a XML::LibXML::Document object. 

Will become a private function soon.

=head2 my $xc=_registerOAI($dom);

Register the uri 'http://www.openarchives.org/OAI/2.0/' as the prefix 'oai' and
return a LibXML::xPathContext object

=head2 _validateOAIresponse ($response, 'lax');

	new version!

 if (!_validateOAIresponse ($response, ['lax'])) {
	fail ('validation reason');
 }

=head2 okIfListRecordsMetadataExists ($dom)

=head2 okIfXpathExists ($doc, $xapth, $message);

DEPRECATED use Test::XPath instead.

=head2 isMetadataFormat ($response, $setSpec, $msg);

TODO DOESNT WORK YET

=head2 isSetSpec ($response, $setSpec, $msg);

UNTESTED

=head2 _okOaiResponse ($dom);

	ok if OAI response contains _no_ error.

	DEPRECATED: use _failIfOAIerror and _failNoOAIerror to replace most of 
	this functionality.

=head2 okValidateOAI($dom);
=func okValidateOAILax ($dom)
Validate if $dom complies with OAI namespace, execute Test::More::ok with 
sensible diagnostic message.

DEPRECATED: use _validateOAIresponse($response, 'lax') instead

=head1 RATIONALE

The new kind of test queues multiple 'tests', but uses Test::More only on the 
last and most specific test. It croaks on earlier tests.

=head1 NEW TESTS

=head2 Verb tests

expect a stringified response; pass if response validates against OAI (or 
OAIlax).

=head2 NEW UTILITIES

=head2 testSequence (%opts);

my @sequence = (
	{ verb => 'Identify' },
	{
		verb           => 'ListIdentifiers',
		metadataPrefix => 'oai_dc'
	}
);

$codeRef=sub {
	my ($provider, $verb, $params)=@_;
	my $response = $provider->$verb( %{$params} );
	ok ($response, 'response exists');
};

testSequence (
	config=>\%config, 
	sequence=>\@sequence, 
	codeRef=>$codeRef
);

=head2 INTERNAL INTERFACE

Should only be used internally.

=head2 OLD TESTS / DEPRECATED

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

