#!/usr/bin/perl -w
#
#  Performance test: hostls
#
use strict;
use c2systest;

test 'host/p01_hostls', sub {
    my $setup = shift;
    my $hc = prepare($setup);

    # Add a few hosts
    foreach (1 .. 10) {
        conn_call($hc, 'hostadd', 'e'.$_, '', '', 'k');
    }

    # Verify
    assert_equals scalar(@{ conn_call($hc, 'hostls') }), 10;

    # Benchmark
    test_timing 'host hostls', sub {
        conn_call($hc, 'hostls');
    };
};

sub prepare {
    my $setup = shift;
    my $hs = setup_add_host($setup);
    setup_add_db($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    
    service_connect($hs);
}
