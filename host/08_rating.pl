#!/usr/bin/perl -w
#
#  Host: test game difficulty rating
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Standard case (just plain setup and see what happens)
test 'host/08_rating/default', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hc = prepare($setup);

    # Check initial ratings. PList has 135% difficulty (set by the upload step), config files have 98%, giving 132% total.
    assert_equals conn_call($hc, qw(shiplistrating S get)), 135;
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 132;

    # Start the game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_game($hc, 1);

    # Verify difficulty. Must still be the same.
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 132;
};

# Explicitly fixing the default ratings
test 'host/08_rating/fixed', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hc = prepare($setup);

    # Check initial ratings and fix them for Host/Master. Should not change outcome.
    assert_equals conn_call($hc, qw(shiplistrating S get)), 135;
    assert_equals conn_call($hc, qw(hostrating H auto show)), 98;
    assert_equals conn_call($hc, qw(hostrating H get)), 98;
    assert_equals conn_call($hc, qw(masterrating M auto show)), 101;
    assert_equals conn_call($hc, qw(masterrating M get)), 101;

    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 132;

    # Start the game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_game($hc, 1);

    # Verify difficulty. Must still be the same.
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 132;
};

# Overriding the default rating for the ship list
test 'host/08_rating/shiplist', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hc = prepare($setup);

    # Override ship list rating.
    conn_call($hc, qw(shiplistrating S set 200 use));
    assert_equals conn_call($hc, qw(shiplistrating S get)), 200;
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 197;

    # Start the game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_game($hc, 1);

    # Verify difficulty. Must still be the same.
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 197;
};

# Overriding the default rating for the Master
test 'host/08_rating/master', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hc = prepare($setup);

    # Override Master rating.
    conn_call($hc, qw(masterrating M set 200 use));
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 263;

    # Start the game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_game($hc, 1);

    # Verify difficulty. Master-provided config imply a 101% difficulty,
    # and since we do no longer know that they came from Master, it goes on top.
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 265;
};

# Overriding the default rating for the Master but don't use it.
test 'host/08_rating/master2', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hc = prepare($setup);

    # Override Master rating with a value for display, but not effective use.
    conn_call($hc, qw(masterrating M set 200 show));
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 132;

    # Start the game
    conn_call($hc, qw(gamesetstate 1 running));
    wait_for_game($hc, 1);

    # Verify difficulty. Must not change.
    assert_equals conn_call($hc, qw(gamegetcc 1 difficulty)), 132;
};

sub wait_for_game {
    my ($hc, $gid) = @_;
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') eq '') {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}

sub prepare {
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');
    my $dbs = setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);

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

    $hc;
}
