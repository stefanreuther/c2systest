#!/usr/bin/perl -w
#
#  Host: with bug #377, the HostFile connection's permissions were not updated.
#  This caused wrong permissions to be applied to host-internal actions,
#  and caused those actions to fail.
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Test turn submission.
test 'host/90_377_permission/trn', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Users
    my $user1 = c2service::setup_add_user($setup, 'u1');
    my $user2 = c2service::setup_add_user($setup, 'u2');
    conn_call($hc, qw(playerjoin 1 1), $user1);
    conn_call($hc, qw(playerjoin 1 2), $user2);

    # Start game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_turn($hc, 1);

    # Access host using different permissions
    # -- This triggers the bug --
    conn_call($hc, qw(user anon));
    conn_call($hc, qw(get shiplist/S/pconfig.src.frag));

    # Submit a turn file for a player
    # -- bug causes this to fail --
    conn_call($hc, 'user', $user1);
    my %result = conn_call_list($hc, 'trn', c2service::vp_make_turn(1, conn_call($hc, qw(gameget 1 timestamp))));
    assert_equals $result{status}, 1;
};

# Test host run.
test 'host/90_377_permission/runhost', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');

    # Users
    my $user1 = c2service::setup_add_user($setup, 'u1');
    my $user2 = c2service::setup_add_user($setup, 'u2');
    conn_call($hc, qw(playerjoin 1 1), $user1);
    conn_call($hc, qw(playerjoin 1 2), $user2);

    # Start game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_turn($hc, 1);

    # Access host using different permissions
    # -- This triggers the bug --
    conn_call($hc, qw(user anon));
    conn_call($hc, qw(get shiplist/S/pconfig.src.frag));

    # Submit a turn file for a player
    conn_call($hc, 'user', '');
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_turn($hc, 2);
    assert_equals conn_call($dbc, qw(scard game:broken)), 0;
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
