use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'           => 'Sys::HostAddr',
    'VERSION_FROM'   => 'HostAddr.pm', # finds $VERSION
    'PREREQ_PM'      => {IO::Socket::INET => 1.25, IO::Socket::SSL => 1.77, Sys::Hostname => 1.1},
    ( $] >= 5.005 ?
      (ABSTRACT_FROM => 'HostAddr.pm',
       AUTHOR        => 'Jeremy Kister <http://jeremy.kister.net/>') : () ),
);
