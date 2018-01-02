#!/usr/bin/perl -w
#
#  Host: host run tests
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Run host with no turn files
test 'host/09_host/no', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);

    # Initialize
    my $hc  = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $trn = conn_call($hc, qw(gameget 1 turn));

    # Run host
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_game($hc, 1, $trn);

    # Verify
    assert_equals conn_call($hc, qw(gameget 1 turn)), $trn+1;
    assert_equals get_turn_from_timestampfile(conn_call($hfc, qw(get games/0001/data/nextturn.hst))), $trn+1;
};

# Run host with regular turn file
test 'host/09_host/one', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);

    # Initialize
    my $SHIP_ID = 158;
    my $hc  = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $trn = conn_call($hc, qw(gameget 1 turn));
    my $ship = get_ship_from_shipfile(conn_call($hfc, qw(get games/0001/data/ship.hst)), $SHIP_ID);

    # Pre-verify
    assert_equals $trn, 131;
    assert_equals $ship->{name}, 'LARGE DEEP SPACE FRE';
    assert_equals $ship->{owner}, 6;

    # Submit a turn file
    my %trn_result = conn_call_list($hc, 'trn', c2service::vp_make_turn(6, conn_call($hfc, qw(get games/0001/data/nextturn.hst)), pack("vvA20", 7, $SHIP_ID, 'New Name')));
    assert_equals $trn_result{status}, 1;

    # Run host with this turn file
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_game($hc, 1, $trn);

    # Verify
    $ship = get_ship_from_shipfile(conn_call($hfc, qw(get games/0001/data/ship.hst)), $SHIP_ID);
    assert_equals conn_call($hc, qw(gameget 1 turn)), $trn+1;
    assert_equals $ship->{name}, 'New Name';
};

# Run host with subscription and non-submitted turn file
test 'host/09_host/forget', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);

    # Initialize
    my $SHIP_ID = 158;
    my $hc  = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $ufc = setup_connect_app($setup, 'file');
    my $trn = conn_call($hc, qw(gameget 1 turn));

    # Add a user and configure its play path
    my $uid = c2service::setup_add_user($setup, 'user');
    conn_call($hc,  'playerjoin', 1, 6, $uid);
    conn_call($hc,  'playersetdir', 1, $uid, 'u/user/gamedir');
    conn_call($ufc, 'put', 'u/user/gamedir/player6.trn', c2service::vp_make_turn(6, conn_call($hfc, qw(get games/0001/data/nextturn.hst)), pack("vvA20", 7, $SHIP_ID, 'Forgotten Name')));

    # Run host
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_game($hc, 1, $trn);

    # Verify
    my $ship = get_ship_from_shipfile(conn_call($hfc, qw(get games/0001/data/ship.hst)), $SHIP_ID);
    assert_equals conn_call($hc, qw(gameget 1 turn)), $trn+1;
    assert_equals $ship->{name}, 'Forgotten Name';
};

# Run host with subscription and non-submitted turn file, multiple players
test 'host/09_host/multi', sub {
    # Set up, start and connect
    my $setup = shift;
    prepare($setup);

    # Initialize
    my $SHIP_ID = 158;
    my $hc  = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $ufc = setup_connect_app($setup, 'file');
    my $trn = conn_call($hc, qw(gameget 1 turn));

    # Add a user and configure its play path
    my $uid1 = c2service::setup_add_user($setup, 'user1');
    my $uid2 = c2service::setup_add_user($setup, 'user2');
    conn_call($hc,  'playerjoin', 1, 6, $uid1);
    conn_call($hc,  'playersubst', 1, 6, $uid2);
    conn_call($hc,  'playersetdir', 1, $uid1, 'u/user1/gamedir');
    conn_call($hc,  'playersetdir', 1, $uid2, 'u/user2/gamedir');
    conn_call($ufc, 'put', 'u/user1/gamedir/player6.trn', c2service::vp_make_turn(6, conn_call($hfc, qw(get games/0001/data/nextturn.hst)), pack("vvA20", 7, $SHIP_ID, 'Name One')));
    conn_call($ufc, 'put', 'u/user2/gamedir/player6.trn', c2service::vp_make_turn(6, conn_call($hfc, qw(get games/0001/data/nextturn.hst)), pack("vvA20", 7, $SHIP_ID, 'Name Two')));

    # Run host
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_game($hc, 1, $trn);

    # Verify
    my $ship = get_ship_from_shipfile(conn_call($hfc, qw(get games/0001/data/ship.hst)), $SHIP_ID);
    assert_equals conn_call($hc, qw(gameget 1 turn)), $trn+1;
    assert_equals $ship->{name}, 'Name One';      # FIXME: should this be Name Two?

    # Verify result files
    my $rst = conn_call($hfc, qw(get games/0001/data/player6.rst));
    assert_equals $rst, conn_call($hfc, qw(get games/0001/out/6/player6.rst));
    assert_equals $rst, conn_call($ufc, qw(get u/user1/gamedir/player6.rst));
    assert_equals $rst, conn_call($ufc, qw(get u/user2/gamedir/player6.rst));
};



sub wait_for_game {
    my ($hc, $gid, $trn) = @_;
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') eq $trn) {
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
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $dbc = setup_connect_app($setup, 'db');

    # Prepare
    # - default files
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);
    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Create a game and add a user
    assert_equals conn_call($hc, 'newgame'), 1;

    # Verify filesystem content
    foreach (qw(games/0001 games/0001/backup games/0001/in games/0001/out games/0001/data)) {
        my %stat = conn_call_list($hfc, 'stat', $_);
        assert_equals $stat{type}, 'dir';
    }

    # Populate the game
    opendir GAME, "data/game" or die "data/game: $!";
    foreach (readdir(GAME)) {
        conn_call($hfc, 'put', 'games/0001/data/'.$_, file_content('data/game/'.$_))
            unless /^\./;
    }
    closedir GAME;

    # Fix up database
    conn_call($dbc, qw(set game:bytime:06-01-201222:46:01 1));
    conn_call($dbc, qw(set game:1:state running));
    conn_call($dbc, qw(hset game:1:settings turn), get_turn_from_timestampfile(file_content('data/game/nextturn.hst')));
    conn_call($dbc, qw(hset game:1:settings masterHasRun 1));
    conn_call($dbc, qw(smove game:state:preparing game:state:running 1));

    # Prepare a schedule
    #   We need a manual schedule to be able to run the host at will.
    #   We must set a lastHostTime to prevent the host from running at the first possible occasion.
    #     This causes the tests (most often, host/09_host/one) to sporadically fail.
    #   We must remove lastScheduleChange to avoid the implicit foot-gun protection that refuses to
    #     run a host directly after a schedule change.
    conn_call($hc, qw(scheduleadd 1 manual));
    conn_call($dbc, qw(hset game:1:settings lastHostTime 1));
    conn_call($dbc, qw(hset game:1:settings lastScheduleChange 0));
}

sub get_turn_from_timestampfile {
    my $ts = shift;
    assert defined($ts);
    assert length($ts) >= 20;
    return unpack "v", substr($ts, 18, 2);
};

sub get_ship_from_shipfile {
    my $file = shift;
    my $id = shift;
    assert defined($file);
    assert length($file) >= 2 + 107*$id;

    my $record = substr($file, 2 + 107*($id-1));
    return { owner => unpack("v",   substr($record, 2, 2)),
             name  => unpack("A20", substr($record, 45, 20)) };
};
