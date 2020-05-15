#!/usr/bin/perl -w
#
#  Test api/play.cgi: clising a managed, finished game
#
#  (closely related to interactive/x04_finished)
#
#  (The original observation was that sessions are not closed if the game is finished,
#  but that turned out to be a bug in the JavaScript.)
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

test 'web/39_playfinished', sub {
    # Setup up. Manually assign a data directory because c2play currently works directly on filespace.
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'userdata');
    mkdir $dir, 0777 or die "$dir: $!";
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));
    setup_add_service_config($setup, 'router.sessionid', 'random');
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    my $rs = setup_add_router($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup, $dir);
    setup_add_hostfile($setup);
    setup_start_wait($setup);

    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $fc = setup_connect_app($setup, 'file');
    my $uc = setup_connect_app($setup, 'user');

    # Basic init
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    my $uid = c2service::setup_add_user($setup, 'user');
    my $cookie = setup_make_cookie($setup, $uid);

    # Add game
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gameset', $gid, 'turn', 10);
    conn_call($hc, 'gameset', $gid, 'hostHasRun', 1);
    conn_call($hc, 'gameset', $gid, 'lastHostTime', 1);         # required to prevent host from running immediately
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetstate', $gid, 'running');

    # Upload an actual game
    $dir = conn_call($hc, 'gamegetdir', $gid);
    foreach (qw(player3.rst util3.dat)) {
        conn_call($hfc, 'put', "$dir/out/3/$_", file_content("data/game/$_"));
    }
    foreach (qw(beamspec.dat engspec.dat hullspec.dat pconfig.src planet.nm race.nm storm.nm torpspec.dat truehull.dat xyplan.dat)) {
        conn_call($hfc, 'put', "$dir/out/all/$_", file_content("data/game/$_"));
    }

    # Set up player
    conn_call($hc, 'playerjoin', $gid, 3, $uid);
    conn_call($hc, 'playersetdir', $gid, $uid, 'u/user/my-game');
    conn_call($fc, 'put', 'u/user/my-game/fizz.bin', file_content(c2service::setup_get_init_scripts($setup).'/r/unreg/fizz.bin'));

    # Finish the game
    conn_call($hc, 'gamesetstate', $gid, 'finished');

    # Open a game session
    my $new_result = setup_post_api($setup, 'api/play.cgi', $cookie, action => 'new', dir => 'u/user/my-game', player => 3);
    assert $new_result;
    assert $new_result->{result};

    # Get list of sessions
    my $new_list = service_call_raw($rs, "list\n");
    assert_contains $new_list, '1 session';

    # Close it
    my $close_result = setup_post_api($setup, 'api/play.cgi', $cookie, action => 'close', sid => $new_result->{sid});
    my $close_list = service_call_raw($rs, "list\n");
    assert_contains $close_list, '0 sessions';
};
