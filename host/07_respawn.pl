#!/usr/bin/perl -w
#
#  Host: test master invocation and respawn
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

test 'host/07_respawn', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');
    my $dbs = setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);
    my $hfc = service_connect($hfs);
    my $dbc = service_connect($dbs);

    # Prepare files
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);

    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Add some games
    assert_equals conn_call($hc, 'newgame'), 1;
    assert_equals conn_call($hc, 'newgame'), 2;

    # Configure the games
    conn_call($hc, qw(gamesetname 1 One));
    conn_call($hc, qw(gamesetname 2 Two));
    conn_call($hc, qw(gameset 1 copyNext 2));
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesettype 2 public));

    # Clone
    assert_equals conn_call($hc, qw(clonegame 1 joining)), 3;
    assert_equals conn_call($hc, qw(gameget 3 copyOf)), 1;
    assert_equals conn_call($hc, qw(gamegetname 3)), 'One 1';

    # Start the game. This will eventually run master.
    conn_call($hc, qw(gamesetstate 3 running));
    wait_for_game($hc, 3);

    # Must now have a fourth game. Start that, too.
    assert_equals conn_call($hc, qw(gameget 4 copyOf)), 2;
    assert_equals conn_call($hc, qw(gamegetname 4)), 'Two 1';
    conn_call($hc, qw(gamesetstate 4 running));
    wait_for_game($hc, 4);

    # Must now have a fifth game. Start that, too.
    assert_equals conn_call($hc, qw(gameget 5 copyOf)), 2;
    assert_equals conn_call($hc, qw(gamegetname 5)), 'Two 2';
};

sub wait_for_game {
    my ($hc, $gid) = @_;
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') eq '') {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}
