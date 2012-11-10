#!/usr/bin/perl
use strict;
use warnings;
use Plack::App::File;
use Plack::Builder;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use WWW::Module::CoreList;

my $inifile = $ENV{CORELISTINI} || "$FindBin::RealBin/../conf/corelist.yaml";
my $cl = WWW::Module::CoreList->init($inifile);
my $conf = $cl->conf;
my $app = sub {
    my ($env) = @_;
    return $cl->run_request($env);
};

builder {
    mount $conf->{self} => $app;
    mount $conf->{static} => Plack::App::File->new(
        root => "$FindBin::RealBin/../htdocs",
    )->to_app;
    mount '/' => $app;
};
