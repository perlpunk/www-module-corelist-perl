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
    $self->cgi($cgi);
#    if ($self->is_post) {
        %submits = map {
            my $key = $_;
            my $value = $cgi->param($key);
            if (m/^submit\.(.*?)(?:\.x|\.y)?$/) {
                    ($1 => $value)
            }
            else { () }
        } $cgi->param();
#    }
    $self->submit(\%submits);
    $self->action($action);
    $self->args(\@args);
#    my $cookies = {};
#    $cookies = $self->cgi_class->{cookie}->fetch;
    #warn Data::Dumper->Dump([\$cookies], ['cookies']);
#    $self->cookies($cookies);
    return $self;
}

sub param {
    my ($self, @args) = @_;
    if (wantarray) {
        my @ret = map { Encode::decode_utf8($_) } $self->cgi->param(@args);
        return @ret;
    }
    return Encode::decode_utf8($self->cgi->param(@args));
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
