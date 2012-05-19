package HTTP::OAI::DataProvider::Test;

use strict;
use warnings;
use Test::More;
use FindBin;
use XML::LibXML;
use Scalar::Util;
use HTTP::OAI::DataProvider::Common qw(valPackageName);
use base 'Exporter';
use vars '@EXPORT_OK';


@EXPORT_OK = qw(
  basicResponseTests
  loadWorkingTestConfig
  okIfIdentifierExists
  okIfMetadataExists
  okOaiResponse
  okValidateOAI

  oaiError
  registerOAI
);

=head1 SIMPLE TESTS


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

=func okIfIdentifierExists ($dom);

oks if response has at least one 
	/oai:OAI-PMH/oai:ListIdentifiers/oai:header[1]/oai:identifier

=cut

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

sub okIfIdentifierExists {
	my $doc = shift or die "Error: Need doc!";
	okIfXpathExists(
		$doc,
		'/oai:OAI-PMH/oai:ListIdentifiers/oai:header[1]/oai:identifier',
		'first header has an identifier'
	);

	#print "DSDSDS:$value\n";
	#print $doc->toString;
}

=func okIfMetadataExists ($dom);

Currently it works only for a GetRecord/record/metadata. Should it also work 
for ListRecords/record/metadata?

=cut

sub okIfMetadataExists {
	my $doc = shift or die "Error: Need doc!";
	okIfXpathExists(
		$doc,
		'/oai:OAI-PMH/oai:GetRecord/oai:record[1]/oai:metadata',
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

	my $xmlschema =
	  XML::LibXML::Schema->new(
		location => 'http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd' )
	  or die "Error: Cant parse schema! Might be temporal problem";

	eval { $xmlschema->validate($doc); };
	ok( !$@, 'document validates against OAI-PMH v2' );

	if ($@) {
		print "$@";
	}
}

=head1 COLLECTIONS OF TESTS

At this point I am not sure if I should prefer a single specific test or a 
series of increasingly tests. The answer depends on the kinds of problems
I anticipate.

=func my $dom=basicResponseTests ($response_as_string);

Expects the output from the verb, a string containing XML. Carries out 4 tests.

1) Does response validate as a OAI response?
2) Does response contain OAI errors?

returns the response as dom.

=cut

sub basicResponseTests {
	my $response = shift or die "Error: Need response!";
	my $dom=response2dom ($response);

	#print $dom->toString;
	okValidateOAI($dom);
	okOaiResponse($dom);
	return $dom;
}

=head1 UTILITY FUNCTIONS/METHODS

=func my $config=HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();

	loadWorkingTestConfig returns a hashref with a working configuration.

=cut

sub loadWorkingTestConfig {

	my $config = do "$FindBin::Bin/test_config"
	  or die "Error: Configuration not loaded";

	#in lieu of proper validation
	die "Error: Not a hashref" if ref $config ne 'HASH';

	return $config;
}

=func $hashref=oaiError($oai_response_as_dom);

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

		if ($code) {
			$error->{$code} = $desc;
			return $error;
		}
	}
	return;
}

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

=func isScalar ($variable);

Dies if $variable is not scalar

=cut

sub isScalar {
	my $value = shift or die "Need value!";
	die "Value is not a scalar"
	  if ( !Scalar::Util::reftype \$value eq 'SCALAR' );
}


=func my $dom=response2dom ($response);

expects a xml as string. Returns a XML::LibXML::Document object.

=cut

sub response2dom {
	my $response = shift or die "Error: Need response!";
	isScalar($response); #die if not scalar

	return XML::LibXML->load_xml( string => $response );
}



1;
