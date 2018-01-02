#!/usr/bin/perl -w
#
#  Host: test master invocation
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

test 'host/06_master', sub {
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

    # Add a game
    assert_equals conn_call($hc, 'newgame'), 1;

    # Configure the game
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));

    # Verify
    assert_equals conn_call($hc, qw(gameget 1 host)), 'H';
    assert_equals conn_call($hc, qw(gameget 1 master)), 'M';
    assert_equals conn_call($hc, qw(gameget 1 shiplist)), 'S';
    assert_equals conn_call($hc, qw(gameget 1 turn)), '';
    assert_equals conn_call($hc, qw(gamegetstate 1)), 'joining';
    assert_equals conn_call($hc, qw(gamegettype 1)), 'public';
    assert_equals conn_call($hc, qw(gamegetdir 1)), 'games/0001';

    # Cron should not have any event for this element now
    my %cron = @{ conn_call($hc, qw(cronget 1)) };
    assert_equals $cron{action}, 'none';

    # Start the game. This will eventually run master.
    conn_call($hc, qw(gamesetstate 1 running));

    # Ask cron. The sleep is to give the scheduler time to pick up the change.
    sleep 0.1;
    %cron = @{ conn_call($hc, qw(cronget 1)) };
    assert_equals $cron{action}, 'master';

    # Config modification must be blocked using '600 Game in use', but config inquiry works.
    assert_throws sub{ conn_call($hc, qw(gameset 1 host H)) }, 600;
    assert_equals      conn_call($hc, qw(gameget 1 host)), 'H';

    # Wait until master completed (at most 10 seconds; typical <3 seconds, of which 2 are a tactical sleep)
    my $loops = 0;
    while (conn_call($hc, qw(gameget 1 turn)) eq '') {
        sleep 0.25;
        assert ++$loops <= 40;
    }

    # Verify presence of game files
    foreach (qw(ship.hst pconfig.src nextturn.hst host.log)) {
        my %stat = @{ conn_call($hfc, 'stat', "games/0001/data/$_") };
        assert_equals $stat{type}, 'file';
    }

    # Verify presence of result files
    foreach (1 .. 11) {
        my $out = conn_call($hfc, 'get', "games/0001/out/$_/player$_.rst");
        my $hst = conn_call($hfc, 'get', "games/0001/data/player$_.rst");
        assert_equals $out, $hst;
    }

    # We did not configure a schedule; thus, there is no cron event
    %cron = @{ conn_call($hc, qw(cronget 1)) };
    assert_equals $cron{action}, 'none';

    # Verify database
    assert_equals conn_call($dbc, qw(hget game:1:settings turn)), 1;
    assert_equals conn_call($dbc, qw(hget game:1:turn:1:scores bases)), "\1\0\0\0" x 11;
    assert_equals conn_call($dbc, qw(hexists game:1:scores bases)), 1;

    my $ts = conn_call($dbc, qw(hget game:1:settings timestamp));
    assert_equals conn_call($dbc, 'get', "game:bytime:$ts"), 1;
    assert_equals conn_call($dbc, qw(hget game:1:turn:1:info timestamp)), $ts;

    # Verify presence of history
    assert_equals conn_call($dbc, qw(llen global:history)), 2;
    my @hist = @{ conn_call($dbc, qw(lrange global:history 0 -1)) };
    assert $hist[0] =~ /^\d+:game-state:1:running$/;
    assert $hist[1] =~ /^\d+:game-state:1:joining$/;

    assert_equals conn_call($dbc, qw(llen game:1:history)), 2;
    my @game_hist = @{ conn_call($dbc, qw(lrange game:1:history 0 -1)) };
    assert_equals $hist[0], $game_hist[0];
    assert_equals $hist[1], $game_hist[1];
};
