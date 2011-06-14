package Dancer::CommandLine;
BEGIN {
  $Dancer::CommandLine::VERSION = '0.006';
}
use strict;
use warnings;

# ABSTRACT: Warning and Debug for Dancer and non-dancing scripts


require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(Debug Warning);  # symbols to export on request

#I use capitalization because i don't know where to turn off redefined warning;


sub Debug {
	if ( defined(&Dancer::Logger::debug) ) {
		Dancer::Logger::debug (@_);
	} else {
		print @_;
	}
}


sub Warning {

	if ( defined(&Dancer::Logger::warning) ) {
		Dancer::Logger::warning (@_);
	} else {
		warn @_;
	}
}

1;    #CommandLine;


1; # End of Dancer::CommandLine

__END__
=pod

=head1 NAME

Dancer::CommandLine - Warning and Debug for Dancer and non-dancing scripts

=head1 VERSION

version 0.006

=head1 SYNOPSIS

	use Dancer::CommandLine qw/Debug Warning/;

	#in your script
	Warning "Write this message using perl's warn";
	Debug "Write this message to STDOUT";

	#in your dancer app
	Warning "Write this message using dancer's warning";
	Debug "Write this message using dancer's debug";

=head1 BACKGROUND

If you want to reuse Dancer code in a script (outside of your webapp, e.g.
command-line tool), Dancer can give you a hard time. This little tool provides
a Debug and Warning function which you can use in both a script and the webapp.

=head1 EXPORT

=head2 Debug "Message";

Use Dancer's debug function if available or write to STDOUT if no Dancer
loaded.

=head2 Warning "Message";

Use Dancer's warning function if available or pass message to perl's warn.

=head1 AUTHOR

Maurice Mengel, C<< <mauricemengel at gmail.com> >>

=head1 BUGS

use GitHub issues please

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::CommandLine

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Maurice Mengel.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 AUTHOR

Maurice Mengel <mauricemengel@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Maurice Mengel.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

