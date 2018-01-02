#!/usr/bin/perl -w
#
#  Speed test for index.cgi
#

use strict;
use c2systest;
use c2cgitest;

test 'web/p01_index', sub {
    # Start all services
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_hostfile($setup, 'auto');
    setup_start_wait($setup);

    # Timing
    test_timing 'web index', sub {
        cgi_run(cgi_new($setup, 'index.cgi'));
    };
};
