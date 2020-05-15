#!/usr/bin/perl -w
#
#  Test slot commands
#
use strict;
use c2systest;
use c2service;

# Test 'slotls'.
# Create a game. 'slotls' must return all slots.
test 'host/21_slot/ls', sub {
    # Set up
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, qw(newgame));

    assert_list_equals [conn_call_list($hc, 'slotls', $gid)], [1..11];
};

# Test 'slotadd', 'slotrm'.
# Create a game. Add/remove slots and verify results.
test 'host/21_slot/addrm', sub {
    # Set up
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, qw(newgame));

    # Remove some slots
    conn_call($hc, 'slotrm', $gid, 3, 4, 5);
    assert_list_equals [conn_call_list($hc, 'slotls', $gid)], [1, 2, 6..11];

    # Add some
    conn_call($hc, 'slotadd', $gid, 2, 3);
    assert_list_equals [conn_call_list($hc, 'slotls', $gid)], [1..3, 6..11];

    # Remove some that are already gone
    conn_call($hc, 'slotrm', $gid, 5, 12, -9);
    assert_list_equals [conn_call_list($hc, 'slotls', $gid)], [1..3, 6..11];

    # Add some out-of-range
    assert_throws sub{ conn_call($hc, 'slotadd', $gid, 12, -9) }, 400;
};

# Test removal conflict.
# Create a game and add a player. It must not be possible to remove that slot.
test 'host/21_slot/conflict', sub {
    # Set up
    my $setup = shift;
    prepare($setup);

    my $uid = c2service::setup_add_user($setup, 'u');
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, qw(newgame));
    conn_call($hc, 'gamesetstate', $gid, 'joining');
    conn_call($hc, 'playerjoin', $gid, 4, $uid);

    assert_throws sub{ conn_call($hc, 'slotrm', $gid, 4) }, 409;
    assert_list_equals [conn_call_list($hc, 'slotls', $gid)], [1..11];
};

# Test running master on a game with reduced slots.
test 'host/21_slot/master', sub {
    # Set up
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, qw(newgame));

    # Set slots
    conn_call($hc, 'slotrm', $gid, 3..7);
    assert_list_equals [conn_call_list($hc, 'slotls', $gid)], [1, 2, 8..11];

    # Start game
    conn_call($hc, 'gamesetstate', $gid, 'running');

    # Wait for master to run
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') ne 1) {
        sleep 0.25;
        assert ++$loops <= 40;
    }

    # Verify file content
    foreach (1, 2, 8..11) {
        assert_differs conn_call($hc, 'get', "game/$gid/$_/player$_.rst"), '';
    }
    foreach (3..7) {
        assert_throws sub{ conn_call($hc, 'get', "game/$gid/$_/player$_.rst") }, 404;
    }

    # Verify files in host
    my $dir = conn_call($hc, 'gamegetdir', $gid);
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $as = conn_call($hfc, 'get', "$dir/data/amaster.src");
    assert $as =~ /RaceIsPlaying *= *yes,yes,no,no,no,no,no,yes,yes,yes,yes/i;

    foreach (1, 2, 8..11) {
        assert_equals conn_call($hc, 'get', "game/$gid/$_/player$_.rst"), conn_call($hfc, 'get', "$dir/data/player$_.rst");
    }

    # Cannot compare this because the user version has normalized newlines, the internal one does not
    # assert_equals conn_call($hc, 'get', "game/$gid/amaster.src"), $as;

    # Verify file list
    my %dir = conn_call_list($hc, 'ls', "game/$gid");
    foreach (1, 2, 8..11) {
        assert $dir{$_};
    }
    foreach (3..7) {
        assert !$dir{$_};
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
