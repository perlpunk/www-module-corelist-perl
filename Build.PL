use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => 'traditional',
    license            => 'perl',
    module_name        => 'WWW::Module::CoreList',
    dist_author        => 'Tina Mueller',
    requires => {
        'HTML::Template::Compiled' => 0.95,
        'HTML::Template::Compiled::Plugin::HTML_Tags' => 0.05,
        'Class::Accessor::Fast' => 0.25,
        'Module::CoreList' => 2.32,
        'Plack' => 0,
        perl => '5.10.0',
        YAML => 0.70,
    },
    dist_abstract => 'Web Interface to Module::CoreList',
    build_requires => {
        'Test::More'          => 0,
    },
    recommends         => {
    },
    create_readme      => 1,
    sign               => 1,
    meta_merge => {
        resources => {
            license     => 'http://dev.perl.org/licenses/',
#            repository  => '',
        },
    },
);
$build->create_build_script;
