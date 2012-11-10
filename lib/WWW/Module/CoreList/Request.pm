package WWW::Module::CoreList::Request;
use strict;
use warnings;
our $VERSION = 0.003;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/
    req action args submit
/);

sub init {
    my ($self, $cl) = @_;
    my $req = $self->req;
    my $path = $req->uri->path;
    my $conf = $cl->conf;
    my $self_url = $conf->{self};
    $path =~ s{^\Q$self_url\E}{};
    $path =~ s{^/}{};
    my ($action, @args) = split m{/}, $path;
    $action ||= 'index';
    $self->action($action);
    $self->args(\@args);
    my %submits;
    %submits = map {
        my $key = $_;
        my $value = $req->param($key);
        if (m/^submit\.(.*?)(?:\.x|\.y)?$/) {
                ($1 => $value)
        }
        else { () }
    } $req->param();
    $self->submit(\%submits);
    return $self;
}

sub args {
    return wantarray ? @{ $_[0]->get('args') } : $_[0]->get('args');
}

sub param {
    my ($self, @args) = @_;
    if (wantarray) {
        my @ret = map { Encode::decode_utf8($_) } $self->req->param(@args);
        return @ret;
    }
    return Encode::decode_utf8($self->req->param(@args));
}

1;
