package WWW::Module::CoreList::Handler2;
use strict;
use warnings;
use Plack::Handler::Apache2;
our $VERSION = 0.003;
use Carp qw(croak carp);
use WWW::Module::CoreList;

sub get_app {
    my ($r) = @_;
    my $inifile = $r->dir_config->get('inifile');
    my $cl = WWW::Module::CoreList->init($inifile);
    my $app = sub {
        my ($env) = @_;
        return $cl->run_request($env);
    };
}

sub handler {
    my $r = shift;
    my $app = get_app($r);
    return Plack::Handler::Apache2->call_app($r, $app);
}

1;

