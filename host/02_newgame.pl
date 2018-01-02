#!/usr/bin/perl -w
#
#  Host: test "newgame" command
#
use strict;
use c2systest;
use c2service;

test 'host/02_newgame', sub {
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

    # Test
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;

    # Verify database content
    assert_equals conn_call($dbc, qw(get game:1:dir)), 'games/0001';
    assert_equals conn_call($dbc, qw(get game:1:name)), 'New Game';
    assert_equals conn_call($dbc, qw(get game:1:owner)), '';
    foreach (1..11) {
        assert_equals conn_call($dbc, 'hget', "game:1:player:$_:status", 'slot'), 1;
        assert_equals conn_call($dbc, 'hget', "game:1:player:$_:status", 'turn'), 0;
    }
    assert_equals conn_call($dbc, qw(get game:1:schedule:lastId)), 0;
    assert_equals conn_call($dbc, qw(hget game:1:settings description)), 'New Game';
    assert_equals conn_call($dbc, qw(hget game:1:settings host)), 'H';
    assert_equals conn_call($dbc, qw(hget game:1:settings master)), 'M';
    assert_equals conn_call($dbc, qw(hget game:1:settings shiplist)), 'S';
    assert_equals conn_call($dbc, qw(get game:1:state)), 'preparing';
    assert_equals conn_call($dbc, qw(get game:1:type)), 'private';
    assert_equals conn_call($dbc, qw(scard game:all)), 1;
    assert_equals conn_call($dbc, qw(sismember game:all 1)), 1;
    assert_equals conn_call($dbc, qw(get game:lastid)), 1;
    assert_equals conn_call($dbc, qw(scard game:state:preparing)), 1;
    assert_equals conn_call($dbc, qw(sismember game:state:preparing 1)), 1;

    # Verify filesystem content
    foreach (qw(games/0001 games/0001/backup games/0001/in games/0001/out games/0001/data)) {
        my %stat = @{ conn_call($hfc, 'stat', $_) };
        assert_equals $stat{type}, 'dir';
    }
};
