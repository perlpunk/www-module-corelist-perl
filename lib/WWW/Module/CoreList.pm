package WWW::Module::CoreList;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/ conf template request stash /);
use CGI;
use HTML::Template::Compiled;
use Module::CoreList;
use WWW::Module::CoreList::Request;
use YAML qw/ LoadFile /;

our $VERSION = 0.001;

sub init {
    my ($class, $inifile) = @_;
    my $conf = LoadFile($inifile);
    my $self = $class->new;
    $self->conf($conf);
    return $self;
}

my %actions = (
    version => 1,
    mversion => 1,
    pversion => 1,
    diff => 1,
    index => 1,
);
my %perl_versions = %Module::CoreList::version;
my @perl_version_options = (map {
    [$_, format_perl_version($_)]
} sort keys %perl_versions);

sub run {
    my ($self) = @_;

    my $cgi_module = 'CGI';
    my ($cgi_class, $cgi_cookie_class, $cgi_util_class)
        = (qw/ CGI CGI::Cookie CGI::Util /);
    if ($cgi_module eq 'CGI::Simple') {
        s/CGI/CGI::Simple/ for ($cgi_class, $cgi_cookie_class, $cgi_util_class);
    }

    my $cgi_classes = {
        cgi    => $cgi_class,
        cookie => $cgi_cookie_class,
        util   => $cgi_util_class,
    };


    my $request = WWW::Module::CoreList::Request->from_cgi(
        CGI->new,
        cgi_class => $cgi_classes,
    );
    $self->request($request);
    my $action = $request->action || 'index';
    my $conf = $self->conf;
    my @seo = @{ $conf->{seo}->{ $action } || [] };
    @seo = qw/ noindex noarchive / unless @seo;
    my $seo = join ',', @seo;
    if ($ENV{QUERY_STRING}) {
        $seo = 'noindex,noarchive';
    }
    my $stash = {
        self => $conf->{self},
        action => $action,
        selected => { $action => 1 },
        seo => {
            index_archive => $seo,
        },
        corelist_version => Module::CoreList->VERSION,
        static => $conf->{static},
    };
    $self->stash($stash);
    if (exists $actions{ $action }) {
        $self->$action();
    }
    else {
        die "unknown action $action";
    }
    my $selected_pv = $self->request->param('perl_version');
    $stash->{perl_versions} = [$selected_pv||'', @perl_version_options];


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
    );
#    warn __PACKAGE__.':'.__LINE__.$".Data::Dumper->Dump([\$stash], ['stash']);
    $htc->param(
        %$stash,
    );
    $self->template($htc);

}

sub output {
    my ($self) = @_;

    my $header = $self->request->cgi->header(
        -charset => 'utf-8',
#        -status => $status,
#            @$cookie
#            ? (-cookie => [map { $_->as_string } @$cookie])
#            : (),
    );

    my $output = $self->template->output;
    return $header, $output, ':encoding(utf-8)';
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
        $module =~ s/^\s+//;
        $module =~ s/\s+$//;
        $self->stash->{p}->{module} = $module;
        my @versions;
        my $found = 0;
        my @list;
        my $fuzzy = $submits->{fuzzy};
        my $version = Module::CoreList->first_release($module);
        my $mversion;
        my $removed;
        if ($version and exists $Module::CoreList::version{$version}) {
            $mversion = $Module::CoreList::version{$version}->{$module};
            $found = 1;
        }
        my $date;
        if ($version) {
            $date = $Module::CoreList::released{$version};
            $removed = Module::CoreList->removed_from($module);
        }
        @versions = {
            name => $module,
            vers => $version,
            formatted => format_perl_version($version),
            mvers => $mversion,
            date => $date,
            removed => $removed,
        };
        if ($submits->{fuzzy} or not $found) {
            push @list, sort Module::CoreList->find_modules(qr/\Q$module/i);
            shift @list if $found;
        }
        for my $mod (@list) {
            my $version = Module::CoreList->first_release($mod);
            my $date;
            my $mv;
            my $removed;
            if ($version) {
                $mv = $Module::CoreList::version{$version}{$mod} || 'undef';
                $date = $Module::CoreList::released{$version};
                $removed = Module::CoreList->removed_from($mod);
            }
            my $entry = {
                name => $mod,
                vers => $version,
                formatted => format_perl_version($version),
                mvers => $mv,
                date => $date,
                removed => $removed,
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
        for my $v (sort keys %Module::CoreList::version) {
            next unless exists $Module::CoreList::version{$v}->{$mod};
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
    $stash->{perl_versions_1} = [$v1, @perl_version_options];
    $stash->{perl_versions_2} = [$v2, @perl_version_options];
    if (! $v1 or ! $v2) {
        my @versions = sort keys %p;
        $stash->{p}->{select} = 1;
    }   
    else {
        $stash->{p}->{show} = 1;
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

sub format_perl_version {
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

    my $inifile = '/path/to/corelist.yaml';
    my $cl = WWW::Module::CoreList->init($inifile);
    $cl->run;
    my ($header, $out, $mode) = $cl->output;
    print $header;
    binmode STDOUT, $mode;
    print $out if defined $out;


=head1 SEE ALSO

L<Module::CoreList>

=head1 AUTHOR

Tina Mueller

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Tina Mueller

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself, either Perl version 5.6.1 or, at your option,
any later version of Perl 5 you may have available.

=cut
