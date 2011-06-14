package HTTP::OAI::DataProvider::Message;
BEGIN {
  $HTTP::OAI::DataProvider::Message::VERSION = '0.006';
}
# ABSTRACT: Debug and warning messages for the data provider

use strict;
use warnings;

require Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(Debug Warning);    # symbols to export on request
our $Debug;
our $Warning;


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


sub Warning {
	if ($HTTP::OAI::DataProvider::Message::Warning) {
		goto $HTTP::OAI::DataProvider::Message::Warning;
	}
}

1; #true;

__END__
=pod

=head1 NAME

HTTP::OAI::DataProvider::Message - Debug and warning messages for the data provider

=head1 VERSION

version 0.006

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

=head2 Warning "Message";

Hands over parameters to callback. Does nothing unless
$HTTP::OAI::DataProvider::Message::Debug is defined.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

