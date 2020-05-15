#!/usr/bin/perl -w
#
#  Test unbreaking a game (cronkick).
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Test unbreaking a game that broke during export.
# Such a game can be unbroken just usign 'cronkick', no db repair needed.
test 'host/20_unbreak', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);
    my $dbc = setup_connect_app($setup, 'db');
    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');

    # Users
    my $user1 = c2service::setup_add_user($setup, 'u1');
    my $user2 = c2service::setup_add_user($setup, 'u2');
    conn_call($hc, qw(playerjoin 1 1), $user1);
    conn_call($hc, qw(playerjoin 1 2), $user2);

    # Start game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_turn($hc, 1);

    # Break the game by removing the host
    conn_call($hfc, qw(rmdir shiplist/S));
    conn_call($hc, qw(gameset 1 hostRunNow 1));

    # Game must be detected as broken
    my $loops = 0;
    while (conn_call($dbc, qw(scard game:broken)) == 0) {
        sleep 0.25;
        assert ++$loops <= 40;
    }

    # Fix it and re-run
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    conn_call($hc, qw(cronkick 1));
    wait_for_turn($hc, 2);
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

sub prepare {
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
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);

    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Add a game
    assert_equals conn_call($hc, 'newgame'), 1;

    # Configure the game
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(scheduleadd 1 manual));
    conn_call($hc, qw(gameset 1 lastHostTime 1));
    conn_call($hc, qw(gameset 1 lastScheduleChange 0));
}
