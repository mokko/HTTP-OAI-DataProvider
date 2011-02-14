package HTTP::OAI::DataProvider::Message;

use strict;
use warnings;

require Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(Debug Warning);    # symbols to export on request
our $Debug;
our $Warning;

=head1 NAME

HTTP::OAI::DataProvider::Debug

=head2 SYNOPSIS

A debug and warning mechanism for HTTP::OAI::DataProvider that does not depend
on a specific framework like Dancer.

	use HTTP::OAI::DataProvider::Message qw/Debug Warning/;
	$HTTP::OAI::DataProvider::Message::Debug = &callback;
	$HTTP::OAI::DataProvider::Message::Warning = &callback;

	Debug "message";
	Warning "message";

=head2 Debug "Message";

Hands over parameters to callback. Does nothing unless
$HTTP::OAI::DataProvider::Message::Debug is defined.

=head2 new

Use a method construction although rest is functional. Well. Still looks ok
to me. TODO

=cut

sub new {
	my $class=shift;
	my %args=@_;

	if ($args{Debug}) {
		$HTTP::OAI::DataProvider::Message::Debug=$args{Debug};
	}

	if ($args{Warning}) {
		$HTTP::OAI::DataProvider::Message::Debug=$args{Warning};
	}
}

sub Debug {
	if ($HTTP::OAI::DataProvider::Message::Debug) {
		goto $HTTP::OAI::DataProvider::Message::Debug;
	}
}

=head2 Warning "Message";

Hands over parameters to callback. Does nothing unless
$HTTP::OAI::DataProvider::Message::Debug is defined.

=cut

sub Warning {
	if ($HTTP::OAI::DataProvider::Message::Warning) {
		goto $HTTP::OAI::DataProvider::Message::Warning;
	}
}

1; #true;
