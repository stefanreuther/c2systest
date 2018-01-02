#!/usr/bin/perl -w
use strict;
use c2systest;
use c2service;


test 'host/15_ref', sub {
    my $setup = shift;
    prepare($setup);

    # Add a referee add-on
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, 'mkdir', 'ref');
    conn_call($hfc, 'put', 'ref/c2post.sh', 'echo End=1 > $1/c2ref.txt');

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'tooladd', 'ref', 'ref', '', 'ref');
    conn_call($hc, 'gameaddtool', 1, 'ref');

    # Run host
    my $trn = conn_call($hc, qw(gameget 1 turn));
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_game($hc, 1, $trn);

    # Game must have ended
    assert_equals conn_call($hc, qw(gamegetstate 1)), 'finished';
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

    # Create a game
    assert_equals conn_call($hc, 'newgame'), 1;

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

    # Prepare a schedule [see 09_host]
    conn_call($hc, qw(scheduleadd 1 manual));
    conn_call($dbc, qw(hset game:1:settings lastHostTime 1));
    conn_call($dbc, qw(hset game:1:settings lastScheduleChange 0));
}

sub wait_for_game {
    my ($hc, $gid, $trn) = @_;
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') eq $trn) {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}

sub get_turn_from_timestampfile {
    my $ts = shift;
    assert defined($ts);
    assert length($ts) >= 20;
    return unpack "v", substr($ts, 18, 2);
};
