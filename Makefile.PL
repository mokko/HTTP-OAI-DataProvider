
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A simple OAI data provider",
  "AUTHOR" => "Maurice Mengel <mauricemengel\@gmail.com>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "HTTP-OAI-DataProvider",
  "EXE_FILES" => [
    "bin/dp.pl",
    "bin/ingest.pl",
    "bin/webapp.pl"
  ],
  "LICENSE" => "perl",
  "NAME" => "HTTP::OAI::DataProvider",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "DBI" => 0,
    "DBIx::Connector" => 0,
    "Dancer" => 0,
    "Encode" => 0,
    "Exporter" => 0,
    "FindBin" => 0,
    "Getopt::Long" => 0,
    "HTTP::OAI" => 0,
    "HTTP::OAI::Repository" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "Path::Class" => 0,
    "Pod::Usage" => 0,
    "Scalar::Util" => 0,
    "Test::More" => 0,
    "Test::XPath" => 0,
    "Time::HiRes" => 0,
    "URI" => 0,
    "XML::LibXML" => 0,
    "XML::LibXML::XPathContext" => 0,
    "XML::LibXSLT" => 0,
    "XML::SAX::Writer" => 0,
    "base" => 0,
    "namespace::autoclean" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Dumper" => 0
  },
  "VERSION" => "0.009",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Cwd" => 0,
  "DBI" => 0,
  "DBIx::Connector" => 0,
  "Dancer" => 0,
  "Data::Dumper" => 0,
  "Encode" => 0,
  "Exporter" => 0,
  "FindBin" => 0,
  "Getopt::Long" => 0,
  "HTTP::OAI" => 0,
  "HTTP::OAI::Repository" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "Moose::Util::TypeConstraints" => 0,
  "Path::Class" => 0,
  "Pod::Usage" => 0,
  "Scalar::Util" => 0,
  "Test::More" => 0,
  "Test::XPath" => 0,
  "Time::HiRes" => 0,
  "URI" => 0,
  "XML::LibXML" => 0,
  "XML::LibXML::XPathContext" => 0,
  "XML::LibXSLT" => 0,
  "XML::SAX::Writer" => 0,
  "base" => 0,
  "namespace::autoclean" => 0,
  "strict" => 0,
  "utf8" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



