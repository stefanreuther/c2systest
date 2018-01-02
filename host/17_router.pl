#!/usr/bin/perl -w
use strict;
use c2systest;
use c2service;


test 'host/17_router', sub {
    my $setup = shift;
    my ($rs, $ufroot) = prepare($setup);

    # Configure a player, join them, and configure a play path
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/a/gamedir));

    # Verify
    my $ufc = setup_connect_app($setup, 'file');
    assert_equals conn_call($ufc, qw(get u/a/gamedir/player3.rst)), file_content('data/game/player3.rst');

    # Start a session
    my $response = service_call_raw($rs, "NEW -WDIR=u/a/gamedir -WDIRPL=u/a/gamedir/3 $ufroot/u/a/gamedir 3\n");
    assert $response =~ /^201\s*(\d+)/;
    my $session_id = $1;

    # Make sure we can talk to this session
    assert service_call_raw($rs, "S $session_id\nGET obj/main\n") =~ /^200/;
    assert service_call_raw($rs, "S $session_id\nGET obj/planetxy\n") =~ /^200/;
    assert service_call_raw($rs, "INFO $session_id\n") =~ /^200/;

    # Upload a turn file. This must close the session.
    conn_call($hc, 'trn', c2service::vp_make_turn(3, '06-01-201222:46:01'));

    # Accesses not give a 452
    assert service_call_raw($rs, "S $session_id\nGET obj/main\n") =~ /^452/;
    assert service_call_raw($rs, "S $session_id\nGET obj/planetxy\n") =~ /^452/;
    assert service_call_raw($rs, "INFO $session_id\n") =~ /^452/;
};



sub prepare {
    my $setup = shift;
    my $ufroot = setup_get_tmpfile_name($setup, 'ufroot');
    mkdir $ufroot, 0777 or die;
    my $rs = setup_add_app($setup, 'router', 'c2router');
    service_set_pingable($rs, 0);
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));
    setup_add_db($setup);
    setup_add_host($setup);
    setup_add_talk($setup);
    setup_add_userfile($setup, $ufroot);
    setup_add_hostfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_start_wait($setup);
    c2service::setup_db_init($setup);
    c2service::setup_add_user($setup, 'a');
    c2service::setup_add_user($setup, 'b');
    c2service::setup_hostfile_add_defaults($setup);

    my $hfc = setup_connect_app($setup, 'hostfile');
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');

    # Dummy scripts
    # Note that c2host-classic expects bin/checkturn.sh to move the turn from in/new/ to in/.
    conn_call($hfc, 'put', 'bin/runhost.sh', 'true');
    conn_call($hfc, 'put', 'bin/checkturn.sh', 'mv "$1/in/new/player$2.trn" "$1/in/player$2.trn"');

    # Dummy tools
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    # Populate the game
    assert_equals conn_call($hc, 'newgame'), 1;
    opendir GAME, "data/game" or die "data/game: $!";
    foreach (readdir(GAME)) {
        conn_call($hfc, 'put', 'games/0001/data/'.$_, file_content('data/game/'.$_))
            unless /^\./;
    }
    closedir GAME;
    conn_call($hfc, 'put', 'games/0001/out/3/player3.rst', file_content('data/game/player3.rst'));

    # Fix up database
    conn_call($dbc, qw(set game:bytime:06-01-201222:46:01 1));
    conn_call($dbc, qw(set game:1:state running));
    conn_call($dbc, qw(hset game:1:settings turn), get_turn_from_timestampfile(file_content('data/game/nextturn.hst')));
    conn_call($dbc, qw(hset game:1:settings masterHasRun 1));
    conn_call($dbc, qw(hset game:1:settings lastHostTime 1));         # required to prevent host from running immediately
    conn_call($dbc, qw(smove game:state:preparing game:state:running 1));

    return ($rs, $ufroot);
}

sub get_turn_from_timestampfile {
    my $ts = shift;
    assert defined($ts);
    assert length($ts) >= 20;
    return unpack "v", substr($ts, 18, 2);
};
