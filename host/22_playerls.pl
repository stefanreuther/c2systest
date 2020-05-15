#!/usr/bin/perl -w
#
#  Test 'playerls' command
#
use strict;
use c2systest;
use c2service;


test 'host/22_playerls', sub {
    my $setup = shift;
    prepare($setup);

    # Create a game
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'scheduleadd', $gid, 'stop');
    conn_call($hc, 'gamesetstate', $gid, 'running');
    conn_call($hc, 'gamesettype', $gid, 'public');

    # Produce history: in turn 1, we had 4 slots, in turn 2, we have 3
    foreach my $p (1 .. 11) {
        conn_call($dbc, 'hmset', "game:$gid:player:$p:status",
                  slot => ($p <= 3 ? 1 : 0),
                  turn => 0);
    }
    conn_call($dbc, 'hmset', "game:$gid:turn:1:info",
              time => 9998,
              turnstatus => pack("v*", (1) x 4, (-1) x 7));
    conn_call($dbc, 'hmset', "game:$gid:turn:2:info",
              time => 9999,
              turnstatus => pack("v*", (1) x 3, (-1) x 8));
    conn_call($dbc, 'hmset', "game:$gid:settings",
              turn => 2);

    conn_call($hc, 'user', 'x');

    # List normally
    {
        my %list = conn_call_list($hc, 'playerls', $gid);
        assert_list_equals [sort keys %list], [1..3];

        my %s1 = @{$list{1}};
        assert_equals $s1{joinable}, 1;
    }

    # List all slots ever
    # Bug: Until 20181028, slot 11 would be listed due to an off-by-one error.
    # Bug: Until 20181028, dead slots would be listed as joinable.
    {
        my %list = conn_call_list($hc, 'playerls', $gid, 'all');
        assert_list_equals [sort keys %list], [1..4];

        my %s1 = @{$list{1}};
        assert_equals $s1{joinable}, 1;

        my %s4 = @{$list{4}};
        assert_equals $s4{joinable}, 0;
    }
};



sub prepare {
    my $setup = shift;
    setup_add_host($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_db($setup);
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
}
