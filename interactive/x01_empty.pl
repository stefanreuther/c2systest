#!/usr/bin/perl -w
#
#  Interactive test: empty services
#

use strict;
use c2systest;
use c2cgitest;

test 'interactive/x01_empty', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_start_wait($setup);

    setup_serve($setup);
};
