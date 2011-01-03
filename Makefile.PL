use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'HTTP::OAI::DataProvider::SQLite',
    AUTHOR              => q{Maurice Mengel <mauricemengel@gmail.com>},
    VERSION_FROM        => 'lib/HTTP/OAI/DataProvider/SQLite.pm',
    ABSTRACT_FROM       => 'lib/HTTP/OAI/DataProvider/SQLite.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'HTTP-OAI-DataProvider-SQLite-*' },
);
