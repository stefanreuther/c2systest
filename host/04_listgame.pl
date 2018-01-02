#!/usr/bin/perl -w
#
#  Host: test "gamelist" command
#
use strict;
use c2systest;
use c2service;

test 'host/04_listgame/all', sub {
    my $setup = shift;
    my $hc = prepare($setup);

    # Prepare: create a bunch of games in different states
    # - 1: public/joining
    assert_equals conn_call($hc, 'newgame'), 1;
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));

    # - 2: unlisted/joining
    assert_equals conn_call($hc, 'newgame'), 2;
    conn_call($hc, qw(gamesettype 2 unlisted));
    conn_call($hc, qw(gamesetstate 2 joining));

    # - 3: public/preparing
    assert_equals conn_call($hc, 'newgame'), 3;
    conn_call($hc, qw(gamesettype 3 public));
    conn_call($hc, qw(gamesetstate 3 preparing));

    # - 4: private/preparing
    assert_equals conn_call($hc, 'newgame'), 4;
    conn_call($hc, qw(gamesettype 4 private));
    conn_call($hc, qw(gamesetstate 4 preparing));
    conn_call($hc, qw(gamesetowner 4 u));

    # Test
    # - admin
    assert_set_equals conn_call($hc, qw(gamelist id)),                           [1,2,3,4];
    assert_set_equals conn_call($hc, qw(gamelist id type public)),               [1,3];
    assert_set_equals conn_call($hc, qw(gamelist id state joining)),             [1,2];
    assert_set_equals conn_call($hc, qw(gamelist id state joining type public)), [1];
    assert_set_equals conn_call($hc, qw(gamelist id state running type public)), [];
    assert_set_equals conn_call($hc, qw(gamelist id state preparing)),           [3,4];

    # - user "u"
    conn_call($hc, qw(user u));
    assert_set_equals conn_call($hc, qw(gamelist id state preparing)),           [4];

    # - user "z"
    conn_call($hc, qw(user z));
    assert_set_equals conn_call($hc, qw(gamelist id state preparing)),           [];
};



sub prepare {
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    my $hc = service_connect($hs);
    c2service::setup_hostfile_add_defaults($setup);

    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    $hc;
}
