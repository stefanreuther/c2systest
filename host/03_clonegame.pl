#!/usr/bin/perl -w
#
#  Host: test "clonegame" command
#
use strict;
use c2systest;
use c2service;

test 'host/03_clonegame', sub {
    # Set up, start and connect
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    my $dbs = setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);
    my $hfc = service_connect($hfs);
    my $dbc = service_connect($dbs);

    # Prepare
    # - default files
    c2service::setup_hostfile_add_defaults($setup);

    # - default tools
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    # Test: create a game and clone it
    assert_equals conn_call($hc, 'newgame'), 1;
    assert_equals conn_call($hc, 'clonegame', 1, 'joining'), 2;

    # Verify database content
    assert_equals conn_call($dbc, qw(get game:2:dir)), 'games/0002';
    assert_equals conn_call($dbc, qw(get game:2:name)), 'New Game 1';        # with numeric suffix
    # FIXME: missing in -classic and -ng: assert_equals conn_call($dbc, qw(get game:2:owner)), '';
    foreach (1..11) {
        assert_equals conn_call($dbc, 'hget', "game:2:player:$_:status", 'slot'), 1;
        assert_equals conn_call($dbc, 'hget', "game:2:player:$_:status", 'turn'), 0;
    }
    # FIXME: missing in -classic and -ng: assert_equals conn_call($dbc, qw(get game:2:schedule:lastId)), 0;
    assert_equals conn_call($dbc, qw(hget game:2:settings description)), 'New Game';
    assert_equals conn_call($dbc, qw(hget game:2:settings host)), 'H';
    assert_equals conn_call($dbc, qw(hget game:2:settings master)), 'M';
    assert_equals conn_call($dbc, qw(hget game:2:settings shiplist)), 'S';
    assert_equals conn_call($dbc, qw(get game:2:state)), 'joining';
    assert_equals conn_call($dbc, qw(get game:2:type)), 'private';
    assert_equals conn_call($dbc, qw(scard game:all)), 2;
    assert_equals conn_call($dbc, qw(sismember game:all 2)), 1;
    assert_equals conn_call($dbc, qw(get game:lastid)), 2;
    assert_equals conn_call($dbc, qw(scard game:state:joining)), 1;
    assert_equals conn_call($dbc, qw(sismember game:state:joining 2)), 1;
    assert_equals conn_call($dbc, qw(hget game:bynameprefix), 'New Game'), 1;

    # Verify filesystem content
    foreach (qw(games/0002 games/0002/backup games/0002/in games/0002/out games/0002/data)) {
        my %stat = @{ conn_call($hfc, 'stat', $_) };
        assert_equals $stat{type}, 'dir';
    }
};
