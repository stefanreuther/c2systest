#!/usr/bin/perl -w
#
#  Host: CommandHandler
#
#  Synced with TestServerHostCommandHandler, 20170925
#
use strict;
use c2systest;
use c2service;

test 'host/50_ch', sub {
    # Start
    my $setup = shift;
    setup_add_db($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_add_host($setup, '-nocron');
    setup_start_wait($setup);

    # Environment
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, 'mkdirhier', 'bin');
    conn_call($hfc, 'mkdirhier', 'games');                 # needed for classic, not ng
    conn_call($hfc, 'mkdirhier', 'defaults');
    conn_call($hfc, 'put', 'bin/checkturn.sh', 'exit 0');

    my $uid = c2service::setup_add_user($setup, 'zz');

    # Calls into CommandHandler
    # - invalid
    my $hc = setup_connect_app($setup, 'host');
    assert_throws sub{ conn_call($hc) };
    assert_throws sub{ conn_call($hc, 'what?') }, 400;

    # - ping
    assert_equals conn_call($hc, qw(PING)), 'PONG';
    assert_equals conn_call($hc, qw(ping)), 'PONG';

    # - user
    conn_call($hc, 'user', '1024');
    conn_call($hc, 'user', '');

    # - help
    assert_num_greater length(conn_call($hc, qw(help))), 30;

    # Actual commands.
    # This produces a working command sequence
    conn_call($hc, 'hostadd',     'H', '', '', 'h');
    conn_call($hc, 'masteradd',   'M', '', '', 'm');
    conn_call($hc, 'shiplistadd', 'S', '', '', 's');
    conn_call($hc, 'tooladd',     'T', '', '', 't');

    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetstate', $gid, 'running');
    conn_call($hc, 'scheduleadd', $gid, 'manual');
    conn_call($hc, 'playerjoin', $gid, 7, $uid);
    conn_call($hc, 'trn', c2service::vp_make_turn(7, '11-22-333344:55:66'), 'game', $gid, 'slot', 7);
    conn_call($hc, 'cronget', $gid);
};
