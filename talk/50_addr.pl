#!/usr/bin/perl -w
#
#  Talk: TalkAddress
#
#  Synced with TestServerTalkTalkAddress, 20190330
#
#  Unlike the unit tests, this uses the actual host/user servers to create dependencies.
#

use strict;
use c2systest;
use c2service;

# TestServerTalkTalkAddress::testParse(): test parse()
test 'talk/50_addr/parse', sub {
    my $setup = shift;
    prepare($setup);
    my $tc = setup_connect_app($setup, 'talk');

    # Normal
    assert_list_equals conn_call($tc, 'addrmparse', "fred"),   ["u:1000"];
    assert_list_equals conn_call($tc, 'addrmparse', "wilma"),  ["u:1001"];
    assert_list_equals conn_call($tc, 'addrmparse', "g:12"),   ["g:12"];
    assert_list_equals conn_call($tc, 'addrmparse', "g:12:3"), ["g:12:3"];

    # Variants
    assert_list_equals conn_call($tc, 'addrmparse', "--fred--"),  ["u:1000"];
    assert_list_equals conn_call($tc, 'addrmparse', "WiLmA"),     ["u:1001"];
    assert_list_equals conn_call($tc, 'addrmparse', "g:012"),     ["g:12"];
    assert_list_equals conn_call($tc, 'addrmparse', "g:012:003"), ["g:12:3"];

    # Errors
    assert_list_equals conn_call($tc, 'addrmparse', ""),             [""];
    assert_list_equals conn_call($tc, 'addrmparse', "barney"),       [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:4294967308"), [""];
    assert_list_equals conn_call($tc, 'addrmparse', "u:"),           [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:"),           [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:-1"),         [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:10"),         [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:12:0"),       [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:12:"),        [""];
    assert_list_equals conn_call($tc, 'addrmparse', "g:12:12"),      [""];
    assert_list_equals conn_call($tc, 'addrmparse', "G:"),           [""];
};

# TestServerTalkTalkAddress::testRenderRaw(): Test render(), raw format.
test 'talk/50_addr/render/raw', sub {
    my $setup = shift;
    prepare($setup);
    my $tc = setup_connect_app($setup, 'talk');

    # Normal
    assert_list_equals conn_call($tc, 'addrmrender', "u:1000"), ["fred"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12"), ["g:12"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:3"), ["g:12:3"];

    # Errors
    assert_list_equals conn_call($tc, 'addrmrender', ""), [""];
    assert_list_equals conn_call($tc, 'addrmrender', "whoops"), [""];
    assert_list_equals conn_call($tc, 'addrmrender', "g:9999"), [""];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:13"), [""];
    assert_list_equals conn_call($tc, 'addrmrender', "u:2222"), [""];
};

# TestServerTalkTalkAddress::testRenderHTML(): Test render(), HTML format.
test 'talk/50_addr/render/html', sub {
    my $setup = shift;
    prepare($setup);
    my $tc = setup_connect_app($setup, 'talk');

    conn_call($tc, 'renderoption', 'format', 'html');

    assert_list_equals conn_call($tc, 'addrmrender', "u:1000"), ["<a class=\"userlink\" href=\"userinfo.cgi/fred\">Fred F</a>"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12"), ["players of <a href=\"host/game.cgi/12-Twelve\">Twelve</a>"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:3"), ["player 3 in <a href=\"host/game.cgi/12-Twelve\">Twelve</a>"];
    assert_list_equals conn_call($tc, 'addrmrender', ""), [""];
};

# TestServerTalkTalkAddress::testRenderOther(): Test render(), other formats.
test 'talk/50_addr/render/other', sub {
    my $setup = shift;
    prepare($setup);
    my $tc = setup_connect_app($setup, 'talk');

    conn_call($tc, 'renderoption', 'baseurl', 'http://x/');

    # Mail
    conn_call($tc, 'renderoption', 'format', 'mail');
    assert_list_equals conn_call($tc, 'addrmrender', "u:1000"), ["<http://x/userinfo.cgi/fred>"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12"), ["players of <http://x/host/game.cgi/12-Twelve>"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:3"), ["player 3 in <http://x/host/game.cgi/12-Twelve>"];
    assert_list_equals conn_call($tc, 'addrmrender', ""), [""];

    # News
    conn_call($tc, 'renderoption', 'format', 'news');
    assert_list_equals conn_call($tc, 'addrmrender', "u:1000"), ["<http://x/userinfo.cgi/fred>"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12"), ["players of <http://x/host/game.cgi/12-Twelve>"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:3"), ["player 3 in <http://x/host/game.cgi/12-Twelve>"];
    assert_list_equals conn_call($tc, 'addrmrender', ""), [""];

    # Text
    conn_call($tc, 'renderoption', 'format', 'text');
    assert_list_equals conn_call($tc, 'addrmrender', "u:1000"), ["fred"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12"), ["players of Twelve"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:3"), ["player 3 in Twelve"];
    assert_list_equals conn_call($tc, 'addrmrender', ""), [""];

    # BBCode
    conn_call($tc, 'renderoption', 'format', 'forum');
    assert_list_equals conn_call($tc, 'addrmrender', "u:1000"), ["[user]fred[/user]"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12"), ["players of [game]12[/game]"];
    assert_list_equals conn_call($tc, 'addrmrender', "g:12:3"), ["player 3 in [game]12[/game]"];
    assert_list_equals conn_call($tc, 'addrmrender', ""), [""];
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_usermgr($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_start_wait($setup);

    # Create two users
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(set user:uid 999));

    my $uc = setup_connect_app($setup, 'user');
    assert_equals conn_call($uc, 'adduser', 'fred', 'secret', 'screenname', 'Fred F'), '1000';
    assert_equals conn_call($uc, 'adduser', 'wilma', 'secret', 'screenname', 'Wilma F'), '1001';

    # Create a game
    my $hc = setup_connect_app($setup, 'host');
    c2service::setup_hostfile_add_defaults($setup);
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    # We want this to be game #12, so create 11 deleted games before
    foreach (1..11) {
        my $gid = conn_call($hc, 'gamesetstate', conn_call($hc, 'newgame'), 'deleted');
    }

    assert_equals conn_call($hc, 'newgame'), 12;
    conn_call($hc, 'gamesetstate', 12, 'joining');
    conn_call($hc, 'gamesettype', 12, 'public');
    conn_call($hc, 'gamesetname', 12, 'Twelve');
}
