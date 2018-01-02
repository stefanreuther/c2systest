#!/usr/bin/perl -w
#
#  Simple performance test
#
#  This generates a performance baseline by testing PING commands on all services.
#

use strict;
use c2systest;

test 'self/p01_ping', sub {
    # Start everything
    my $setup = shift;
    my %services = ( db      => setup_add_db($setup),
                     host    => setup_add_host($setup),
                     file    => setup_add_hostfile($setup, 'auto'),
                     format  => setup_add_app($setup, 'format', 'c2format'),
                     mailout => setup_add_mailout($setup),
                     talk    => setup_add_talk($setup));
    setup_add_userfile($setup, 'auto');        # needed for host
    setup_start_wait($setup);

    # Connect everything
    foreach (sort keys %services) {
        my $conn = service_connect($services{$_});
        test_timing "$_ ping", sub {
            conn_call($conn, 'ping');
        };
    }
};
