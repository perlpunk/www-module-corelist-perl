#!/usr/bin/perl5.10
use strict;
use warnings;

use WWW::Module::CoreList;
# preload corelist object and template files
my $inifile = '/.../www-module-corelist-perl/conf/corelist.yaml';
my $cl = WWW::Module::CoreList->init($inifile);


1;
