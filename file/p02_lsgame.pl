#!/usr/bin/perl -w
#
#  Performance test: lsgame
#

use strict;
use c2systest;
use c2service;

test 'file/p02_lsgame/5', sub {
    my $setup = shift;
    do_test($setup, 5);
};

test 'file/p02_lsgame/20', sub {
    my $setup = shift;
    do_test($setup, 20);
};

# Perform the test.
# The initial observation was 39 ms (classic) vs 0.5 ms (ng) for an organically grown tree with 25 games.
# As usual, time seems to dominated by network transport time for classic.
sub do_test {
    my ($setup, $N) = @_;

    # Setup.
    # Use a real directory (not an internal one) to allow comparisons against c2file-classic.
    my $file = setup_add_userfile($setup, 'auto');
    setup_start_wait($setup);

    # Set up a list of games
    my $fc = service_connect($file);
    conn_call($fc, qw(mkdir u));
    foreach (1 .. $N) {
        conn_call($fc, 'mkdir', "u/game$_");
        conn_call($fc, 'put', "u/game$_/player3.rst", c2service::vp_make_empty_result_file(3, '11-22-333344:55:66'));
        conn_call($fc, 'put', "u/game$_/race.nm", c2service::vp_race_names());
        conn_call($fc, 'propset', "u/game$_", 'name', "Game $_");
        conn_call($fc, 'propset', "u/game$_", 'game', $_);
    }

    # Verify
    my @r = conn_call_list($fc, qw(lsgame u));
    assert_equals scalar(@r), $N;

    # Test
    test_timing "file lsgame ($N)", sub {
        conn_call($fc, qw(lsgame u));
    };
};
