package HTTP::OAI::DataProvider::Test;

use strict;
use warnings;
use Test::More;
use Test::Xpath;
use FindBin;
use XML::LibXML;

#use Scalar::Util;
use HTTP::OAI::DataProvider::Common qw(valPackageName isScalar);
use HTTP::OAI::DataProvider::Valid;
use base 'Exporter';
use vars '@EXPORT_OK';
use vars '@EXPORT';

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
  
  failOnRequestError

  loadWorkingTestConfig
  xpathTester
  oaiErrorResponse
);

#old stuff deprecated? Should be removed?
@EXPORT_OK = qw(
  okIfIdentifierExists

  okOaiResponse
  okValidateOAI
  okValidateOAILax

  isOAIerror
  isMetadataFormat
  isSetSpec

  oaiError
);

=head1 RATIONALE

The new kind of test queues multiple 'tests', but uses Test::More only on the 
last and most specific test. It dies on earlier tests.

=head1 NEW TESTS

=head2 Verb tests

expect a stringified response; pass if response validates against OAI (or 
OAIlax).

=func okGetRecord($response[,'optional alternative msg']);
=func okIdentify($response[,'optional alternative msg']);
=func okListIdentifiers($response[,'optional alternative msg']);

=func okListRecords($response[,'optional alternative msg']);
=func okListMetadataFormats($response[,'optional alternative msg']);
=func okListSets($response[,'optional alternative msg']);

New version of tests. Validates and checks if element named after verb (aka 
'the type') exists.

=cut

sub okGetRecord {
	my $response = shift or die "Need xml as string!";
	_okType( $response, 'GetRecord', shift );
}

sub okIdentify {
	my $response = shift or die "Need xml as string!";
	_okType( $response, 'Identify', shift );
}

sub okListIdentifiers {
	my $response = shift or die "Need xml as string!";
	_okType( $response, 'ListIdentifiers', shift );
}

sub okListRecords {
	my $response = shift or die "Need xml as string!";
	_okType( $response, 'ListRecords', shift );
}

sub okListMetadataFormats {
	my $response = shift or die "Need xml as string!";
	_okType( $response, 'ListMetadataFormats', shift );
}

sub okListSets {
	my $response = shift or die "Need xml as string!";
	_okType( $response, 'ListSets', shift );
}

#generic for okIfListIdentifiers,okIfIdentify etc.
sub _okType {
	my $response = shift or die "Need xml as string!";
	my $type     = shift or die "Need type!";
	my $msg = shift || "response validates and is of type $type\n";
	isScalar($response);
	if (
		$type !~ /^Identify$|
		^GetRecord$|
		^ListIdentifiers$|
		^ListMetadataFormats$|
		^ListRecords$|
		^ListSets$/x
	  )
	{
		die "Error: Unknown type ($type)!";
	}

	my $xpath = "/oai:OAI-PMH/oai:$type";
	my $lax = ( $type =~ /^ListRecords$|^GetRecord$/ ) ? 'lax' : '';

	print "LAX:$lax|type:$type\n";
	if ( !_validateOAIresponse( $response, $lax ) ) {
		fail '$type response does not validate $lax';
	}

	_failIfOAIerror( _response2dom($response) );

	my $xt = xpathTester($response);

	#print $response."\n";
	$xt->ok( $xpath, $msg );

}

=func isLMFprefix ($response, 'prefix');

test if ListMetadataFormats response contains a specific prefix.

=cut

sub isLMFprefix {
	my $response = shift or die "Need response";
	my $prefix   = shift or die "Need prefix";
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

=head3 OAI Error tests

=func isOAIerror ($response, $code);

passes if $response is of error type $code

=cut

sub isOAIerror {
	my $response = shift or die "Need response!";
	my $code     = shift or die "Need error type to look for!";
	isScalar($response);
	isScalar($code);
	if ($code !~ /badArgument|cannotDisseminate|noRecordMatches|idDoesNotExist/) {
		print "Unrecognized OAI error code\n"; 
	}

	my $dom = _response2dom($response);
	_failValidationError($dom);
	my $oaiError = _failNoOAIerror($dom);

	ok( defined $oaiError->{$code}, "expect OAIerror of type '$code'" );
}

=func okIfBadArgument ($response);

passes if response is OAI error badArgument.

DEPRECATED! 
Instead use: 
	C<isOAIerror ($response, 'badArgument');>

=cut

sub okIfBadArgument {
	my $response = shift or die "Error: Need response!";
	isOAIerror( $response, 'badArgument' );
}

=head2 NEW UTILITIES

=func my $config =
	  HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

	loadWorkingTestConfig returns a hashref with a working configuration .

=cut

sub loadWorkingTestConfig {

	my $config = do "$FindBin::Bin/test_config"
	  or die "Error: Configuration not loaded";

	#in lieu of proper validation
	die "Error: Not a hashref" if ref $config ne 'HASH';

	return $config;
}

=func my $err=oaiErrorResponse ($response)

=cut

sub oaiErrorResponse {
	my $response = shift or die "Need response!";
	isScalar($response);
	my $dom = _response2dom($response);
	return oaiError($dom);
}

=func $hashref=oaiError($oai_response_as_dom);

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
=cut

sub oaiError {
	my $doc = shift or die "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $xc    = registerOAI($doc);
	my $error = {};

	#todo: this should be foreach to check for multiple errors
	if ( $xc->exists('/oai:OAI-PMH/oai:error') ) {
		my $code = $xc->findvalue('/oai:OAI-PMH/oai:error/@code');
		my $desc = '';
		$desc = $xc->findvalue('/oai:OAI-PMH/oai:error');

		#print "badewanne".$doc->toString."\n";
		if ($code) {
			$error->{$code} = $desc;
			return $error;
		}
	}
	return;
}

=func failOnRequestError(%params);

Expects the parameters you are about to hand over to data provider as a hash.
Fails with meaninggful error message and exists if the parameters are not 
valid. (Wrapper around HTTP::OAI::Repository::validate_request.)

=cut

sub failOnRequestError {
	if ( my @e = HTTP::OAI::Repository::validate_request(@_) ) {
		fail "Query error: " . grep ($_->code, @e) . "\n";
		exit 1;
	}
}


=func my $xt=xpathTester($response);

returns an Test::XPath object, so you can do things like:
	$xt->ok($xpath, 'msg');

See L<Test::XPath> for details

=cut

sub xpathTester {
	my $response = shift or die "Need response!";
	isScalar $response;
	return Test::XPath->new(
		xml   => $response,
		xmlns => { oai => 'http://www.openarchives.org/OAI/2.0/' },
	);
}

=head2 INTERNAL INTERFACE

Should only be used internally.

=cut

sub _failNoOAIerror {
	my $dom = shift or die "Need dom!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $oaiError = oaiError($dom);
	if ( !$oaiError ) {
		fail 'No error where OAI error expected!';
		exit 1;
	}
	return $oaiError;
}

sub _failIfOAIerror {
	my $dom = shift or die "Need dom!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $oaiError = oaiError($dom);
	if ($oaiError) {
		my @e = keys %{$oaiError};
		fail "Error:Unexpected OAI error (@e)!";
		exit 1;
	}
}

sub _failValidationError {
	my $dom = shift or die "Need dom!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $v   = new HTTP::OAI::DataProvider::Valid;
	my $err = $v->validate($dom);
	if ( $err ne 'ok' ) {
		fail "Response not valid!";
		exit 1;
	}
}

=func my $dom=_response2dom ($response);

expects a xml as string. Returns a XML::LibXML::Document object. 

Will become a private function soon.

=cut

sub _response2dom {
	my $response = shift or die "Error: Need response!";
	isScalar($response);    #die if not scalar

	return XML::LibXML->load_xml( string => $response );
}

###
###
###

=head2 OLD TESTS / DEPRECATED

=func okIfListRecordsMetadataExists ($dom)

=cut

sub okIfListRecordsMetadataExists {
	my $doc = shift or die "Error: Need doc!";
	okIfXpathExists(
		$doc,
		'/oai:OAI-PMH/oai:ListRecords/oai:record[1]/oai:metadata',
		'first record has metadata'
	);
}

=func okIfXpathExists ($doc, $xapth, $message);

=cut

sub okIfXpathExists {
	my $doc = shift or die "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $xpath = shift or die "Error: Need xpath!";

	#TODO validate xpath

	my $msg = shift || '';

	my $xc    = registerOAI($doc);
	my $value = $xc->findvalue($xpath);

	ok( $value, $msg );
}

=func okIfIdentifierExists ($dom);

oks if response has at least one 
	/oai:OAI-PMH/oai:ListIdentifiers/oai:header[1]/oai:identifier

DEPRECATED

=cut

sub _okIfIdentifierExists {
	my $doc = shift or die "Error: Need doc!";
	okIfXpathExists(
		$doc,
		'/oai:OAI-PMH/oai:ListIdentifiers/oai:header[1]/oai:identifier',
		'first header has an identifier'
	);

	#print "DSDSDS:$value\n";
	#print $doc->toString;
}

=func isMetadataFormat ($response, $setSpec, $msg);

TODO DOESNT WORK YET

=cut

sub isMetadataFormat {
	my $response = shift or die "Need response!";
	my $prefix   = shift or die "Need prefix!";
	my $msg = shift || '';    #optional
	isScalar($response);
	isScalar($prefix);
	isScalar($msg);

	my $xpath = '/oai:OAI-PMH/oai:ListMetadataFormats/oai:metadataFormat/'
	  . "oai:metadataPrefix[. = $prefix]";

	my $xt = xpathTester($response);
	$xt->ok( $xpath, $prefix, $msg );
}

=func isSetSpec ($response, $setSpec, $msg);

UNTESTED

=cut

sub isSetSpec {
	my $response = shift or die "Need response!";
	my $setSpec  = shift or die "Need setSpec!";
	isScalar($response);
	isScalar($setSpec);
	my $msg   = "setSpec '$setSpec' exists";
	my $xpath = "/oai:OAI-PMH/oai:ListSets/oai:set[oai:setSpec = $setSpec]";

	my $xt = xpathTester($response);
	$xt->is( $xpath, $setSpec, $msg );
}

=func okIfMetadataExists ($dom);

Currently it works only for a GetRecord/record/metadata. Should it also work 
for ListRecords/record/metadata?

DEPRECATED

=cut

sub _okIfMetadataExists {
	my $doc = shift or die "Error: Need doc!";
	okIfXpathExists(
		$doc,
		' / oai : OAI-PMH / oai : GetRecord / oai : record [1] /oai:metadata',
		'first GetRecord record has a metadata element'
	);

	#print $doc->toString;

}

=func okOaiResponse ($dom);

	ok if OAI response contains _no_ error.

=cut

sub okOaiResponse {
	my $doc = shift or die "Error: Need doc!";
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

=func okValidateOAI($dom);

Validate if $dom complies with OAI namespace, execute Test::More::ok with 
sensible diagnostic message.

=cut

sub okValidateOAI {
	my $doc = shift or die "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $v   = new HTTP::OAI::DataProvider::Valid;
	my $msg = $v->validate($doc);

	ok( $msg eq 'ok', 'document validates against OAI-PMH v2' . $@ );
}

sub okValidateOAILax {
	my $doc = shift or die "Error: Need doc!";
	valPackageName( $doc, 'XML::LibXML::Document' );

	my $v   = new HTTP::OAI::DataProvider::Valid;
	my $msg = $v->validateLax($doc);

	ok( $msg eq 'ok', 'document validates against OAI-PMH v2-lax' . $@ );
}

=func _validateOAIresponse ($response)

	new version!

 if (!_validateOAIresponse ($response, ['lax'])) {
	fail ('reason');
 }

=cut

sub _validateOAIresponse {
	my $response = shift or die "Error: Need doc!";
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
	return 0;        #failure;
}

=head1 DEPRECATED UTILITY FUNCTIONS

=func my $xc=registerOAI($dom);

Register the uri 'http://www.openarchives.org/OAI/2.0/' as the prefix 'oai' and
return a LibXML::xPathContext object

=cut

sub registerOAI {
	my $dom = shift or die "Error: Need doc!";
	valPackageName( $dom, 'XML::LibXML::Document' );

	my $xc = XML::LibXML::XPathContext->new($dom);
	$xc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );
	return $xc;
}

1;
