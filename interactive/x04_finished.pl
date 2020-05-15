#!/usr/bin/perl -w
#
#  Interactive test: managed, finished game
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

test 'interactive/x03_unreg', sub {
    # Setup up. Manually assign a data directory because c2play currently works directly on filespace.
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'userdata');
    mkdir $dir, 0777 or die "$dir: $!";
    setup_add_service_config($setup, 'www.messagehtml', 'Use <em>user</em>, <em>pass</em> to log in.');
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));
    setup_add_service_config($setup, 'router.sessionid', 'random');
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    setup_add_router($setup);
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
    conn_call($uc, 'passwd', $uid, 'pass');

    # Default reg
    conn_call($fc, 'mkdirhier', 'r');
    conn_call($fc, 'setperm',   'r', '*', 'rl');
    conn_call($fc, 'mkdirhier', 'd');
    conn_call($fc, 'setperm',   'd', '*', 'rl');

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

    setup_serve($setup);
};
