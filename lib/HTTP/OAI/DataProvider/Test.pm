package HTTP::OAI::DataProvider::Test;

use strict;
use warnings;
use Test::More;
use FindBin;
use XML::LibXML;
use Scalar::Util;
use base 'Exporter';
use vars '@EXPORT_OK';

@EXPORT_OK = qw(
  basicResponseTests 
  loadWorkingTestConfig
  okIfIdentifierExists
  okOaiResponse
  okValidateOAI

  oaiError
  registerOAI
);

=head1 SIMPLE TESTS

=func okIfIdentifierExists ($dom);

oks if response has at least one 
	/oai:OAI-PMH/oai:ListIdentifiers/oai:header[1]/oai:identifier

=cut

sub okIfIdentifierExists {
	my $doc = shift or die "Error: Need doc!";
	valPackageName($doc, 'XML::LibXML::Document');

	my $xc    = registerOAI($doc);
	my $value=$xc->findvalue ('/oai:OAI-PMH/oai:ListIdentifiers/oai:header[1]/oai:identifier');	

	ok ($value, 'first header has an identifier');
	
	#print "DSDSDS:$value\n";
	#print $doc->toString;	
}


=func okOaiResponse ($dom);

	ok if OAI response contains no error

=cut

sub okOaiResponse {
	my $doc = shift or die "Error: Need doc!";
	valPackageName($doc, 'XML::LibXML::Document');

	my $err = oaiError($doc);
	if ($err) {
		print "   OAI-Error:\n";
		foreach my $code (keys %{$err}){
			print "   $code->".$err->{$code}."\n";
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
	valPackageName($doc, 'XML::LibXML::Document');

	my $xmlschema =
	  XML::LibXML::Schema->new(
		location => 'http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd' )
	  or die "Error: Cant parse schema! Might be temporal problem";

	eval { $xmlschema->validate($doc); };
	ok( !$@, 'document validates against OAI-PMH v2' );
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
	my $response=shift or die "Error: Need response!";

	valScalar($response); 
	print ref $response;
	
	
	my $dom = XML::LibXML->load_xml( string => $response );
	#print $dom->toString;
	okValidateOAI ($dom);
	okOaiResponse ($dom);
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
	valPackageName($doc, 'XML::LibXML::Document');

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
	valPackageName ($dom, 'XML::LibXML::Document');

	my $xc = XML::LibXML::XPathContext->new($dom);
	$xc->registerNs( 'oai', 'http://www.openarchives.org/OAI/2.0/' );
	return $xc;
}


=func valPackageName ($obj,'Package::Name');

Dies with error message if $obj is not blessed with Package::Name. You can specify
more than one package name. Continues if any of them machtes. You may think of 
package names as class types.

=cut

sub valPackageName {
	my $doc = shift or die "Error: Need doc!";
	my @expected = @_ or die "Error: Need object type (package name)";

	my @match=grep (Scalar::Util::blessed($doc) eq $_, @expected);
	
	if ( scalar @match == 0 ) {
		die "Error: Wrong type! Expected one of @expected, but instead it's ".blessed ($doc);
	}
}

sub valScalar {
	my $value=shift or die "Need value!";
	die "Value is not a scalar" if (! Scalar::Util::reftype \$value eq 'SCALAR');
}


1;
