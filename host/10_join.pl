#!/usr/bin/perl -w
#
#  Host: joining/resigning
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Run host with no turn files
test 'host/10_join', sub {
    # Set up, start and connect
    my $setup = shift;
    setup_add_host($setup);
    setup_add_db($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Prepare files
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);
    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Add a game and start it
    my $hc = setup_connect_app($setup, 'host');
    assert_equals conn_call($hc, 'newgame'), 1;
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_game($hc, 1, '');

    my $dbc = setup_connect_app($setup, 'db');
    my $ufc = setup_connect_app($setup, 'file');
    my $hfc = setup_connect_app($setup, 'hostfile');

    # Add user to game and join; verify
    my $a = c2service::setup_add_user($setup, 'a');
    assert_equals $a, 1001;
    conn_call($hc, qw(playerjoin 1 4 1001));
    assert_equals conn_call($dbc, qw(hget user:1001:games 1)), 1;
    assert_equals conn_call($dbc, qw(hget game:1:users 1001)), 1;
    assert_equals conn_call($dbc, qw(llen game:1:player:4:users)), 1;
    assert_equals conn_call($dbc, qw(lindex game:1:player:4:users 0)), 1001;

    # Configure a path name; verify
    conn_call($hc, qw(playersetdir 1 1001 u/a/dir));
    assert_equals conn_call($dbc, qw(hget game:1:user:1001 gameDir)), 'u/a/dir';
    assert_equals conn_call($ufc, qw(get u/a/dir/player4.rst)), conn_call($hfc, qw(get games/0001/data/player4.rst));
    assert_equals conn_call($ufc, qw(propget u/a/dir game)), 1;
    assert_throws sub { conn_call($ufc, qw(get u/a/dir/player6.rst)) }, 404;

    # Join another race; verify
    conn_call($hc, qw(playerjoin 1 6 1001));
    assert_equals conn_call($dbc, qw(hget user:1001:games 1)), 2;
    assert_equals conn_call($dbc, qw(hget game:1:users 1001)), 2;
    assert_equals conn_call($dbc, qw(llen game:1:player:4:users)), 1;
    assert_equals conn_call($dbc, qw(llen game:1:player:6:users)), 1;
    assert_equals conn_call($dbc, qw(lindex game:1:player:6:users 0)), 1001;
    assert_equals conn_call($ufc, qw(get u/a/dir/player4.rst)), conn_call($hfc, qw(get games/0001/data/player4.rst));
    assert_equals conn_call($ufc, qw(get u/a/dir/player6.rst)), conn_call($hfc, qw(get games/0001/data/player6.rst));
    
    # Resign once; verify
    conn_call($hc, qw(playerresign 1 4 1001));
    assert_equals conn_call($dbc, qw(hget user:1001:games 1)), 1;
    assert_equals conn_call($dbc, qw(hget game:1:users 1001)), 1;
    assert_equals conn_call($dbc, qw(llen game:1:player:4:users)), 0;
    assert_equals conn_call($dbc, qw(llen game:1:player:6:users)), 1;
    assert_throws sub { conn_call($ufc, qw(get u/a/dir/player4.rst)) }, 404;
    assert_equals conn_call($ufc, qw(get u/a/dir/player6.rst)), conn_call($hfc, qw(get games/0001/data/player6.rst));
    assert_equals conn_call($ufc, qw(propget u/a/dir game)), 1;

    # Resign other; verify
    # The configured game directory is left there, but the association to the game is dropped.
    conn_call($hc, qw(playerresign 1 6 1001));
    assert_equals conn_call($dbc, qw(hget user:1001:games 1)), 0;
    assert_equals conn_call($dbc, qw(hget game:1:users 1001)), 0;
    assert_equals conn_call($dbc, qw(llen game:1:player:4:users)), 0;
    assert_equals conn_call($dbc, qw(llen game:1:player:6:users)), 0;
    assert_throws sub { conn_call($ufc, qw(get u/a/dir/player4.rst)) }, 404;
    assert_equals conn_call($ufc, qw(get u/a/dir/player6.rst)), conn_call($hfc, qw(get games/0001/data/player6.rst));
    assert_equals conn_call($ufc, qw(propget u/a/dir game)), 0;
};



sub wait_for_game {
    my ($hc, $gid, $trn) = @_;
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') eq $trn) {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}
