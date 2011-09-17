package WWW::Module::CoreList::Request;
use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak carp);

use strict;
use warnings;
use Carp qw(carp croak);
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/
    cgi action args submit cookies
    language path_info cgi_class
/);

sub parse_args {
    my ($self, $cgi) = @_;
    my $pi = $cgi->path_info;
    $pi =~ s#^/##;
    my $args;

    $args = $pi;
    my ($action, @args) = split m#/#, $args;
    return ($action, @args);
}

sub args {
    return wantarray ? @{ $_[0]->get('args') } : $_[0]->get('args');
}

sub cookie {
    my ($self, $name) = @_;
    my $cookies = $self->cookies;
    my $cookie = $cookies->{$name} or return;
    my @value = $cookie->value;
    return @value;
}


sub from_cgi {
    my ($class, $cgi, %args) = @_;
    my $default_language = $args{default_language} || 'de';
    #warn __PACKAGE__.$".Data::Dumper->Dump([\%args], ['args']);
    my $self = $class->new({
            docroot => $args{docroot},
            cgi_class => $args{cgi_class},
        });
    # prevent memleak
    my ($action, @args) = $class->parse_args($cgi);
    $self->path_info('/' . join '/', grep defined, $action, @args);
    my %submits;
    # only set submit buttons if method is post (security)
    $self->cgi($cgi);
    if ($self->is_post) {
        %submits = map {
            my $key = $_;
            my $value = $cgi->param($key);
            if (m/^submit\.(.*?)(?:\.x|\.y)?$/) {
                    ($1 => $value)
            }
            else { () }
        } $cgi->param();
    }
    warn __PACKAGE__.':'.__LINE__.": SUBMIT: @{[ sort keys %submits ]}\n" if keys %submits;;
    $self->submit(\%submits);
    $self->action($action);
    $self->args(\@args);
#    my $cookies = {};
#    $cookies = $self->cgi_class->{cookie}->fetch;
    #warn Data::Dumper->Dump([\$cookies], ['cookies']);
#    $self->cookies($cookies);
    my %language_cookie = $self->cookie('battie_prefs_lang');
    my $preferred;
    my @lang;
    if ($language_cookie{lang}) {
        $preferred = $language_cookie{lang};
    }
    else {
        my $language = $cgi->http('Accept-language') || $default_language;
        @lang = split m/,/, $language;
        # TODO
        #warn __PACKAGE__.':'.__LINE__.": Accept-language: (@lang)\n";
        for my $lang (@lang) {
            my ($l, $weight) = split m/;/, $lang;
            $weight =~ s/^q=// if $weight;
            $lang = [$l, $weight];
        }
        $preferred = shift @lang;
        $preferred = $preferred->[0];
        $preferred =~ tr/-/_/;
    }
    $preferred = {
        de => 'de_DE',
        de_de => 'de_DE',
        en => 'en_US',
        en_gb => 'en_US',
        en_us => 'en_US',
    }->{lc $preferred} || 'en_US';
    $self->language([ $preferred, @lang ]);
    return $self;
}

sub param {
    my ($self, @args) = @_;
    my $is_ajax = $self->cgi->param('is_ajax');
    if (wantarray) {
        my @ret;
        if ($is_ajax) {
            @ret = $self->cgi->param(@args);
            #@ret = map { Encode::encode_utf8($_) } $self->cgi->param(@args);
        }
        else {
            @ret = map { Encode::decode_utf8($_) } $self->cgi->param(@args);
        }
        return @ret;
    }
    if ($is_ajax) {
        return $self->cgi->param(@args);
    }
    else {
        return Encode::decode_utf8($self->cgi->param(@args));
    }
}
sub request_method {
    my ($self, @args) = @_;
    return $self->cgi->request_method(@args);
}
sub is_post {
    my ($self, @args) = @_;
    return lc $self->cgi->request_method() eq 'post' ? 1 : 0;
}


1;
