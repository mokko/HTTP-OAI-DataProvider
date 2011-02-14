use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'HTTP::OAI::DataProvider',
    AUTHOR              => q{Maurice Mengel <mauricemengel@gmail.com>},
    VERSION_FROM        => 'lib/HTTP/OAI/DataProvider.pm',
    ABSTRACT_FROM       => 'lib/HTTP/OAI/DataProvider.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    test      => {TESTS => join( ' ', (glob( 't/*.t'), glob('t/*/*.t')))},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'HTTP-OAI-DataProvider-*' },
);
