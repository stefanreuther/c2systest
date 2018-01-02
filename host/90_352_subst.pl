#!/usr/bin/perl -w
#
#  Host: gamecheckperm command [bug #352]
#
use strict;
use c2systest;
use c2service;

test 'host/90_352_subst', sub {
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

    # Create a game
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(gamesettype 1 public));

    # Use player privileges to join and substitute
    conn_call($hc, qw(user a));
    conn_call($hc, qw(playerjoin 1 11 a));
    conn_call($hc, qw(playersubst 1 11 a));

    # Verify
    my %stat = @{ conn_call($hc, qw(playerstat 1 11)) };
    assert_equals scalar(@{$stat{users}}), 1;
    assert_equals $stat{users}[0], 'a';
};
