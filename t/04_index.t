use Test::More tests => 3;
use strict;
use warnings;
BEGIN {
    use_ok('WWW::Module::CoreList');
}
eval {
    require HTML::TreeBuilder::XPath;
};
my $treebuilder = $@ ? 0 : 1;

SKIP: {
    skip "No HTML::TreeBuilder::XPath installed", 2 unless $treebuilder;
    my $inifile = 't/test_corelist.yaml';
    my $cl = WWW::Module::CoreList->init($inifile);
    $cl->run;
    my ($status, $header, $out) = $cl->output;
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($out);

    my ($robots) = $tree->findnodes( '/html/head/meta[@name="robots"]');
    my $content = $robots->attr('content');
    my $conf = $cl->conf;
    my $seo = $conf->{seo}->{index};
    cmp_ok($content, 'eq', join(',', @$seo), "robots meta tag");

    my @divs = $tree->findnodes( '/html/body/div[@id="content"]/div');
    my %check;
    @check{( 'first release', 'module versions', 'perl versions', 'diff' ) } = ();
    for my $div (@divs) {
        my $h = $div->findvalue('h1');
        if (exists $check{lc $h}) {
            delete $check{lc $h};
        }
    }
    cmp_ok(keys %check, '==', 0, 'function divs found');

#    print $out;


}
