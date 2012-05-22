
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A simple OAI data provider",
  "AUTHOR" => "Maurice Mengel <mauricemengel\@gmail.com>",
  "BUILD_REQUIRES" => {
    "Slurp" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "HTTP-OAI-DataProvider",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "HTTP::OAI::DataProvider",
  "PREREQ_PM" => {
    "Carp" => 0,
    "DBI" => 0,
    "DBIx::Connector" => 0,
    "Dancer" => 0,
    "Dancer::CommandLine" => 0,
    "Encode" => 0,
    "Exporter" => 0,
    "File::Spec" => 0,
    "FindBin" => 0,
    "HTTP::OAI" => 0,
    "HTTP::OAI::Repository" => 0,
    "Moose" => 0,
    "Scalar::Util" => 0,
    "Test::More" => 0,
    "Test::Xpath" => 0,
    "Time::HiRes" => 0,
    "XML::LibXML" => 0,
    "XML::LibXML::XPathContext" => 0,
    "XML::LibXSLT" => 0,
    "XML::SAX::Writer" => 0,
    "YAML::Syck" => 0,
    "base" => 0,
    "parent" => 0,
    "strict" => 0,
    "vars" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.006",
  "test" => {
    "TESTS" => "t/*.t t/02-Common/*.t t/03-Test/*.t t/04-Valid/*.t t/05_chunkCache/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



