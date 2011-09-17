package WWW::Module::CoreList::Handler2;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);
use Time::HiRes qw(gettimeofday tv_interval);
use WWW::Module::CoreList;

my %cl;

sub handler {
    my $r = shift;
    my $start_time = [gettimeofday];
    my $inifile = $r->dir_config->get('inifile');
    unless ($cl{ $inifile }) {
        warn __PACKAGE__.':'.__LINE__.": WWW::Module::CoreList->init\n";
        $cl{ $inifile } = WWW::Module::CoreList->init($inifile);
    }
    my $cl = $cl{ $inifile };
    $cl->run;
    {
        my ($header, $out, $mode) = $cl->output;
        print $header;
        binmode STDOUT, $mode;
        eval {
            print $out if defined $out;
        };
        if ($@) {
            # e.g. "Software caused connection abort"
            warn "ERROR in print: $@";
        }
    }
    my $elapsed = tv_interval ( $start_time );
#    warn __PACKAGE__.':'.__LINE__.": Elapsed: $elapsed\n";
    return Apache2::Const::OK;
}

1;

