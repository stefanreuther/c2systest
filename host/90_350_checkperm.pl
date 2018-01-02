#!/usr/bin/perl -w
#
#  Host: gamecheckperm command [bug #350]
#
use strict;
use c2systest;
use c2service;

test 'host/90_350_checkperm', sub {
    # Set up, start and connect
    my $setup = shift;
    setup_add_host($setup);
    setup_add_db($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Prepare
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);

    # Prepare users. Host verifies user existence on join!
    my $dbc = setup_connect_app($setup, 'db');
    foreach (qw(a b c d e f g h i ... x y z)) {
        conn_call($dbc, 'sadd', 'user:all', $_);
    }

    # Prepare tools
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'hostadd', 'h', '', '', 'h');
    conn_call($hc, 'masteradd', 'm', '', '', 'm');
    conn_call($hc, 'shiplistadd', 's', '', '', 's');

    # Create a game
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetowner 1 z));

    # Join players
    conn_call($hc, qw(playerjoin  1 1 a));
    conn_call($hc, qw(playerjoin  1 2 b));
    conn_call($hc, qw(playersubst 1 2 c));
    conn_call($hc, qw(playerjoin  1 3 d));
    conn_call($hc, qw(playersubst 1 3 e));
    conn_call($hc, qw(playersubst 1 3 f));

    # Verify
    assert_equals conn_call($hc, qw(gamecheckperm 1 a)), 6;        # primary+active
    assert_equals conn_call($hc, qw(gamecheckperm 1 b)), 2;        # primary
    assert_equals conn_call($hc, qw(gamecheckperm 1 c)), 4;        # active
    assert_equals conn_call($hc, qw(gamecheckperm 1 d)), 2;        # primary
    assert_equals conn_call($hc, qw(gamecheckperm 1 e)), 8;        # inactive
    assert_equals conn_call($hc, qw(gamecheckperm 1 f)), 4;        # active
    assert_equals conn_call($hc, qw(gamecheckperm 1 y)), 16;       # public
    assert_equals conn_call($hc, qw(gamecheckperm 1 z)), 1;        # owner

    # Combinations
    conn_call($hc, qw(playerjoin 1 4 f));
    conn_call($hc, qw(playerjoin 1 5 z));
    assert_equals conn_call($hc, qw(gamecheckperm 1 f)), 6;        # active+primary
    assert_equals conn_call($hc, qw(gamecheckperm 1 z)), 7;        # active+primary+owner
};
