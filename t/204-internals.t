use strict;
use warnings;
use Test::More tests => 2;
use HTTP::OAI::DataProvider;
use HTTP::OAI::DataProvider::Test;
use HTTP::OAI;

#use XML::LibXML;

my %config   = HTTP::OAI::DataProvider::Test::loadWorkingTestConfig();
my $provider = new HTTP::OAI::DataProvider(%config);

#TODO: could be XPATH test...
#I could also test the HTTP::OAI::Response or the HTTP::OAI::Error object  
{
	$provider->OAIerrors->errors(
		new HTTP::OAI::Error( code => 'badArgument' ) );
	my $str = $provider->_output( $provider->OAIerrors );
	ok( $str =~ /badArgument/, 'response has one error' );
}

{
	$provider->OAIerrors->errors(
		new HTTP::OAI::Error( code => 'badArgument' ) );
	$provider->OAIerrors->errors(
		new HTTP::OAI::Error( code => 'cannotDisseminate' ) );
	my $response = $provider->OAIerrors;
	my $str      = $provider->_output($response);

	ok( ( $str =~ /cannotDisseminate/ && $str =~ /badArgument/ ),
		'response has two errors' );
}

=head2 OAI Errors

The OAI specification says that one response should be able to contain
multiple OAI errors, such cannotDisseminateFormat AND idDoesNotExist.
L<http://www.openarchives.org/OAI/openarchivesprotocol.html#ErrorConditions>

The resulting XML would look like this:
	<?xml version="1.0" encoding="UTF-8"?>
	<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" 
	         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/
	         http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
	  <responseDate>2002-05-01T09:18:29Z</responseDate>
	  <request>http://arXiv.org/oai2</request>
	  <error code="cannotDisseminateFormat">some other text</error>
	  <error code="idDoesNotExist">some text</error>
	</OAI-PMH>


HTTP::OAI's error object does not allow lists of OAI errors. Is it possible
at all to transform multiple OAI Errors into a single XML response?

my $response = new HTTP::OAI::Response;
$response->errors(new HTTP::OAI::Error( code => 'cannotDisseminateFormat' ));
$response->errors(new HTTP::OAI::Error( code => 'idDoesNotExist' ));

print $response->toDOM->toString. "\n";
=cut

