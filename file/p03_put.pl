#!/usr/bin/perl -w

use strict;
use c2systest;

test 'p03_put', sub {
    my $setup = shift;
    setup_add_userfile($setup, 'auto');
    setup_start_wait($setup);

    my $fc = setup_connect_app($setup, 'file');
    conn_call($fc, 'mkdirhier', 'games/0001/data');
    test_timing 'file put 5M', sub {
        foreach (1 .. 50) {
            conn_call($fc, 'put', "games/0001/data/$_.dat", "\0" . (chr($_) x 100000));
        }
        foreach (1 .. 50) {
            conn_call($fc, 'rm', "games/0001/data/$_.dat");
        }
    };
};
