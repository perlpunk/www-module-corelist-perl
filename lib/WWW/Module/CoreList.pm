package WWW::Module::CoreList;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use Encode;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/ conf template request stash /);
use Plack::Request;
use HTML::Template::Compiled;
use Module::CoreList;
use WWW::Module::CoreList::Request;
use YAML qw/ LoadFile /;

our $VERSION = 0.003;

my %cl;
sub init {
    my ($class, $inifile) = @_;
    unless ($cl{ $inifile }) {
        warn __PACKAGE__.':'.__LINE__.": WWW::Module::CoreList->init($inifile)\n";
        my $conf = LoadFile($inifile);
        my $self = $class->new;
        $self->conf($conf);
        $cl{ $inifile } = $self;
        if ($conf->{cache_dir}) {
            my $count = HTML::Template::Compiled->preload($conf->{cache_dir});
            warn __PACKAGE__.':'.__LINE__.": preloaded $count templates from $conf->{cache_dir}\n";
        }
    }
    return $cl{ $inifile };
}

my %actions = (
    version => 1,
    mversion => 1,
    pversion => 1,
    diff => 1,
    index => 1,
    about => 1,
);
my %lc;
# prepare for case insensitive searching - faster then a regex search
{
    my %seen;
    for my $pv (keys %Module::CoreList::version) {
        my $modules = $Module::CoreList::version{ $pv };
        for my $mod (keys %$modules) {
            next if $seen{ $mod }++;
            my $lower = lc $mod;
            # array - there are modules like PerlIO::scalar and PerlIO::Scalar
            push @{ $lc{ $lower } }, $mod;
        }
    }
}
my %seen_alias;
my @perl_version_options_date = (map {
    my $formatted = format_perl_version($_);
    $seen_alias{ $formatted }++ ? () :
    [$_, format_perl_version($_) . " (" . $Module::CoreList::released{$_} . ")"]
} reverse sort keys %Module::CoreList::version);

sub finish {
    my ($self) = @_;
    $self->request(undef);
}

sub run_request {
    my ($self, $env) = @_;
    $self->run($env);
    my ($status, $headers, $body) = $self->output;
    $self->finish;
    return [ $status, $headers, [$body]];
}

sub run {
    my ($self, $env) = @_;
    $env ||= {};
    my $req = Plack::Request->new($env);
    my $request = WWW::Module::CoreList::Request->new({
        req => $req,
    })->init($self);
    $self->request($request);

    my $action = $request->action;
    my $conf = $self->conf;
    my @seo = @{ $conf->{seo}->{ $action } || [] };
    @seo = qw/ noindex noarchive / unless @seo;
    my $seo = join ',', @seo;
    if ($ENV{QUERY_STRING}) {
        $seo = 'noindex,noarchive';
    }
    my $stash = {
        version => $conf->{version},
        self => $conf->{self},
        action => $action,
        selected => { $action => 1 },
        seo => {
            index_archive => $seo,
        },
        corelist_version => Module::CoreList->VERSION,
        static => $conf->{static},
        allow_regex => $conf->{allow_regex},
    };
    $self->stash($stash);
    if (exists $actions{ $action }) {
        $self->$action();
    }
    else {
        die "unknown action $action";
    }
    my $selected_pv = $self->request->param('perl_version');
    $stash->{perl_versions} = [$selected_pv||'', @perl_version_options_date];


    my $htc = HTML::Template::Compiled->new(
        path            => $self->conf->{templates},
        cache           => 1,
        debug           => 0,
        cache_dir       => $self->conf->{cache_dir},
        tagstyle        => [qw/ -classic -comment +asp +tt /],
        plugin          => [qw( ::HTML_Tags ), ],
        use_expressions => 1,
        default_escape  => 'HTML',
        filename        => 'index.html',
        search_path_on_include => 1,
        loop_context_vars       => 1,
        expire_time     => $self->{conf}->{template_expire} || 60*60*24,
    );
    $htc->param(
        %$stash,
    );
    $self->template($htc);

}

sub output {
    my ($self) = @_;
    my $headers = [
        'Content-Type', 'text/html; charset=utf-8',
    ];
    my $output = encode_utf8( $self->template->output );
    return 200, $headers, $output;
}

sub index {
    my ($self) = @_;
}

sub version {
    my ($self) = @_;
    my $request = $self->request;
    my $submits = $request->submit;
    my $module = $request->param('module');
    if ($module) {
        my $regex_search = $submits->{regex} && $self->{conf}->{allow_regex};
        $module =~ s/^\s+//;
        $module =~ s/\s+$//;
        $module =~ s{^/+}{};
        $self->stash->{p}->{module} = $module;
        my @versions;
        my $found = 0;
        my @list;
        my $version = Module::CoreList->first_release($module);
        my $mversion;
        my $removed;
        my $removed_formatted;
        if ($version and exists $Module::CoreList::version{$version}) {
            $mversion = $Module::CoreList::version{$version}->{$module};
            $found = 1;
        }
        my $date;
        if ($version) {
            $date = $Module::CoreList::released{$version};
            $removed = Module::CoreList->removed_from($module);
            $removed_formatted = format_perl_version($removed);
        }
        @versions = {
            name => $module,
            vers => $version,
            formatted => format_perl_version($version),
            mvers => $mversion,
            date => $date,
            removed => $removed,
            removed_formatted => $removed_formatted,
        };
        if (not $submits->{substr} and not $found and not $regex_search) {
            # try case insensitive
            my $lower = lc $module;
            if (exists $lc{ $lower }) {
                my @entries = $self->_first_release(@{ $lc{ $lower } });
                push @versions, @entries;
                $found = 1;
            }
        }
        if ($regex_search) {
            my $re = eval { qr/$module/ };
            my @mods = Module::CoreList->find_modules($re);
            if (@mods) {
                my @entries = $self->_first_release(@mods);
                push @versions, @entries;
                $found = 1;
            }
        }
        elsif ($submits->{substr} or not $found) {
            push @list, sort Module::CoreList->find_modules(qr/\Q$module/i);
            if ($found) {
                @list = grep { $_ ne $module } @list;
            }
        }
        for my $mod (@list) {
            my $version = Module::CoreList->first_release($mod);
            my $date;
            my $mv;
            my $removed;
            my $removed_formatted;
            if ($version) {
                $mv = $Module::CoreList::version{$version}{$mod} || 'undef';
                $date = $Module::CoreList::released{$version};
                $removed = Module::CoreList->removed_from($mod);
                $removed_formatted = format_perl_version($removed);
            }
            my $entry = {
                name => $mod,
                vers => $version,
                formatted => format_perl_version($version),
                mvers => $mv,
                date => $date,
                removed => $removed,
                removed_formatted => $removed_formatted,
            };
            push @versions, $entry;
        }
        my $sort_by = 'n';
        if (($request->param('sort') || 'n') eq 'v') {
            @versions = sort {
                $a->{vers} cmp $b->{vers}
            } @versions;
            $sort_by = 'v';
        }
        $self->stash->{show_version} = {
            versions => \@versions,
            module => $module,
            $sort_by eq 'v' ? (
                sort_by_v => 1, sort_by_n => 0
            ) : (
                sort_by_v => 0, sort_by_n => 1
            ),
        };
    }
    else {
        $self->stash->{form} = 1;
    }

}
sub _first_release {
    my ($self, @mods) = @_;
    my @versions;
    for my $mod (@mods) {
        my $mversion;
        my $removed;
        my $version = Module::CoreList->first_release($mod);
        if ($version and exists $Module::CoreList::version{$version}) {
            $mversion = $Module::CoreList::version{$version}->{$mod};
        }
        my $date;
        my $removed_formatted;
        if ($version) {
            $date = $Module::CoreList::released{$version};
            $removed = Module::CoreList->removed_from($mod);
            $removed_formatted = format_perl_version($removed);
        }
        my $entry = {
            name => $mod,
            vers => $version,
            formatted => format_perl_version($version),
            mvers => $mversion,
            date => $date,
            removed => $removed,
            removed_formatted => $removed_formatted,
        };
        push @versions, $entry;
    }
    return @versions;
}

sub mversion {
    my ($self) = @_;
    my $request = $self->request;
    my $submits = $request->submit;
    my $mod = $request->param('module');
    if (defined $mod and length $mod) {
        $mod =~ s/^\s+//;
        $mod =~ s/\s+$//;
        $self->stash->{p}->{module} = $mod;
        my @versions;
        my %seen;
        for my $v (sort keys %Module::CoreList::version) {
            next unless exists $Module::CoreList::version{$v}->{$mod};
            my $hashref = $Module::CoreList::version{$v};
            next if $seen{$hashref}++; # $version{'5.016000'} = $version{5.016};
            my $mv = $Module::CoreList::version{$v}{$mod};
            my $date = $Module::CoreList::released{$v};
            my $entry = {
                name => $mod,
                vers => $v,
                formatted => format_perl_version($v),
                mvers => $mv,
                date => $date,
            };
            push @versions, $entry;
        }
        unless (@versions) {
            push @versions, {
                name => $mod,
                vers => undef,
                mvers => undef,
                date => undef,
            };
        }
        $self->stash->{show_version} = {
            versions => \@versions,
            module => $mod,
        };
    }
}

sub pversion {
    my ($self) = @_;
    my $request = $self->request;
    my $submits = $request->submit;

    my $v = $request->param('perl_version') || '';
    my @versions;
    $self->stash->{p}->{perl_version} = $v;
    $self->stash->{p}->{perl_version_formatted} = format_perl_version($v);
    if (exists $Module::CoreList::version{$v}) {
        for my $mod (sort keys %{ $Module::CoreList::version{$v} }) {
            my $mv = $Module::CoreList::version{$v}->{$mod} || 'undef';
            my $date = $Module::CoreList::released{$v};
            my $version = Module::CoreList->first_release($mod);

            my $entry = {
                name => $mod,
                vers => $v,
                formatted => format_perl_version($v),
                mvers => $mv,
                date => $date,
            };
            push @versions, $entry;
        }
    }
    $self->stash->{show_version} = {
        versions => \@versions,
        pversion => $v,
   };
}

sub diff {
    my ($self) = @_;
    my $request = $self->request;
    my $submits = $request->submit;

    my $v1 = $request->param('v1');
    my $v2 = $request->param('v2');
    my %p = %Module::CoreList::version;
    my $show_removed = $request->param('removed') ? 1 : 0;
    my $show_added = $request->param('added') ? 1 : 0;
    my $show_version = $request->param('version') ? 1 : 0;
    my $show_none = $request->param('none') ? 1 : 0;
    my $stash = $self->stash;
    $stash->{p}->{show_removed} = $show_removed;
    $stash->{p}->{show_added} = $show_added;
    $stash->{p}->{show_version} = $show_version;
    $stash->{p}->{show_none} = $show_none;
    if (! $v1 or ! $v2) {
        my @versions = sort keys %p;
        $stash->{p}->{select} = 1;
        $stash->{perl_versions_1} = [undef, @perl_version_options_date];
        $stash->{perl_versions_2} = [undef, @perl_version_options_date];
    }   
    else {
        $stash->{p}->{show} = 1;
        if ($v1 > $v2) {
            ($v2, $v1) = ($v1, $v2);
        }
        $stash->{perl_versions_1} = [$v1, @perl_version_options_date];
        $stash->{perl_versions_2} = [$v2, @perl_version_options_date];
        my $m1 = {};
        if (exists $p{$v1}) {
            $m1 = $p{$v1};
        }
        my $m2 = {};
        if (exists $p{$v2}) {
            $m2 = $p{$v2};
        }
        my %total = (%$m1, %$m2);
        my @difflist;
        for my $mod (sort keys %total) {
            my $diff = 'none';
            no warnings 'uninitialized';
            if (exists $m1->{$mod} and not exists $m2->{$mod}) {
                $diff = 'removed';
            }
            elsif (not exists $m1->{$mod} and exists $m2->{$mod}) {
                $diff = 'added';
            }
            elsif ($m1->{$mod} ne $m2->{$mod}) {
                $diff = 'version';
            }
            push @difflist, {
                name => $mod,
                diff => $diff,
                m1 => $m1->{$mod},
                m2 => $m2->{$mod},
            };
        }
        $stash->{difflist} = \@difflist;
        $stash->{v1} = $v1;
        $stash->{v2} = $v2;

    }
}

sub about {
}

sub format_perl_version {
    no warnings 'uninitialized';
    my $v = shift;
    return $v if $v < 5.006;
    return version::->new($v)->normal;
}



1;

__END__

=pod

=head1 NAME

WWW::Module::CoreList - A web interface to Module::CoreList

=head1 SYNOPSIS

You can run this web application on your own server:

    # run with Plack:
    # plackup bin/app.psgi
    # or
    # CORELISTINI=/path/to/corelist.yaml plackup bin/app.psgi

    # run with mod_perl in Apache:
    <Perl>
    use lib '/.../www-module-corelist-perl/lib';
    </Perl>
    PerlPostConfigRequire /.../www-module-corelist-perl/bin/mod_perl_startup.pl
    <Location /corelist>
        SetHandler perl-script
        PerlSetVar inifile /.../www-module-corelist-perl/conf/corelist.yaml
        PerlResponseHandler WWW::Module::CoreList::Handler2
    </Location>
    Alias /cl/ /.../www-module-corelist-perl/htdocs/

=head1 SEE ALSO

L<Module::CoreList>

=head1 AUTHOR

Tina Mueller

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2012 by Tina Mueller

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself, either Perl version 5.6.1 or, at your option,
any later version of Perl 5 you may have available.

=cut
