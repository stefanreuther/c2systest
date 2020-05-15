#!/usr/bin/perl -w
#
#  Host: test kickAfterMissed
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Test kickAfterMissed.
# Configures kickAfterMissed, creates a game.
# Verifies that players are kicked at the appropriate times.
test 'host/18_kick', sub {
    # Set up, start and connect
    my $setup = shift;
    setup_add_host($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');

    # Prepare files
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    my $user1 = c2service::setup_add_user($setup, 'u1');
    my $user2 = c2service::setup_add_user($setup, 'u2');
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);

    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Add a game
    assert_equals conn_call($hc, 'newgame'), 1;

    # Configure the game
    conn_call($hc, qw(gameset 1 kickAfterMissed 3));
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(playerjoin 1 1), $user1);
    conn_call($hc, qw(playerjoin 1 2), $user2);
    conn_call($hc, qw(scheduleadd 1 manual));
    conn_call($hc, qw(gameset 1 lastHostTime 1));
    conn_call($hc, qw(gameset 1 lastScheduleChange 0));

    # Start game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_turn($hc, 1);

    # Verify history: nobody submits a turn for turn 1
    assert_equals conn_call($dbc, qw(hget game:1:turn:1:info turnstatus)), "\0" x 22;

    # Submit turn file for player 1
    conn_call($hc, 'trn', c2service::vp_make_turn(1, conn_call($hc, qw(gameget 1 timestamp))));

    # Run host
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_turn($hc, 2);

    # Verify history
    assert_equals conn_call($dbc, qw(hget game:1:turn:2:info turnstatus)), "\1\0" . ("\0" x 20);

    # Run one more turn
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_turn($hc, 3);
    assert_equals conn_call($dbc, qw(hget game:1:turn:3:info turnstatus)), "\0" x 22;
    assert_list_equals conn_call($hc, 'gamelist', 'user', $user1, 'id'), [1];
    assert_list_equals conn_call($hc, 'gamelist', 'user', $user2, 'id'), [1];

    # Run one more turn. Player 2 has not submitted a turn for three turns now and will be kicked.
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_turn($hc, 4);
    assert_equals conn_call($dbc, qw(hget game:1:turn:4:info turnstatus)), "\0" x 22;
    assert_list_equals conn_call($hc, 'gamelist', 'user', $user1, 'id'), [1];
    assert_list_equals conn_call($hc, 'gamelist', 'user', $user2, 'id'), [];

    # Final turn. Player 1 will be kicked, too.
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_turn($hc, 5);
    assert_equals conn_call($dbc, qw(hget game:1:turn:5:info turnstatus)), "\0" x 22;
    assert_list_equals conn_call($hc, 'gamelist', 'user', $user1, 'id'), [];
    assert_list_equals conn_call($hc, 'gamelist', 'user', $user2, 'id'), [];

    # Verify history
    # Top (front) are the "kick" entries.
    my @history = conn_call_list($dbc, 'lrange', 'game:1:history', 0, -1);
    assert_equals scalar(@history), 6;
    assert_contains $history[0], "game-kick:1:$user1:1";
    assert_contains $history[1], "game-kick:1:$user2:2";
    assert_contains $history[2], "game-state:1:running";
    assert_contains $history[3], "game-join-other:1:$user2:2";
    assert_contains $history[4], "game-join-other:1:$user1:1";
    assert_contains $history[5], "game-state:1:joining";
};



sub wait_for_turn {
    my $hc = shift;
    my $turn = shift;
    my $loops = 0;
    while (conn_call($hc, qw(gameget 1 turn)) ne $turn) {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}
