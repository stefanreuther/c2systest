#!/usr/bin/perl -w
#
#  Interactive test: managed game with no registration
#
#  (To test the game setup flow)
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

test 'interactive/x03_unreg', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'www.messagehtml', 'Use <em>user</em>, <em>pass</em> to log in.');
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    setup_add_router($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup);
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
    conn_call($fc, 'mkdirhier', 'r/unreg');
    conn_call($fc, 'setperm',   'r/unreg', '*', 'rl');
    conn_call($fc, 'setperm',   'r',       '*', 'rl');
    conn_call($fc, 'mkdirhier', 'd');
    conn_call($fc, 'setperm',   'd', '*', 'rl');
    conn_call($fc, 'put', 'r/unreg/fizz.bin', file_content(c2service::setup_get_init_scripts($setup).'/r/unreg/fizz.bin'));

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

    # Dummy files
    my $dir = conn_call($hc, 'gamegetdir', $gid);
    foreach (1..11) {
        conn_call($hfc, 'put', "$dir/out/$_/player$_.rst", "rst $_");
    }
    conn_call($hfc, 'put', "$dir/out/all/spec.dat", "spec");

    # Set up player
    conn_call($hc, 'playerjoin', $gid, 3, $uid);
    conn_call($hc, 'playersetdir', $gid, $uid, 'u/user/my-game');

    setup_serve($setup);
};
