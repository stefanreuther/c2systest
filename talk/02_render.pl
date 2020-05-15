#!/usr/bin/perl -w
#
#  Test rendering user names
#

use strict;
use c2systest;
use c2service;

test 'talk/02_render/user', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create some users
    my $one = c2service::setup_db_add_user($setup, 'one');
    my $two = c2service::setup_db_add_user($setup, 'two');

    # Configure users
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'hset', "user:$one:profile", 'screenname', 'First');
    conn_call($dbc, 'hset', "user:$two:profile", 'screenname', 'Second');

    # Configure talk
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'renderoption', 'baseurl', 'http://base/');

    # Test attributions
    assert_equals conn_call($tc, 'render', 'forum:[quote=one]Hi[/quote]', 'format', 'html'),
        join("\n",
             '<div class="attribution"><a class="userlink" href="http://base/userinfo.cgi/one">First</a>:</div>',
             '<blockquote><p>Hi</p>',
             '</blockquote>',
             '');
    assert_equals conn_call($tc, 'render', 'forum:[quote=one]Hi[/quote]', 'format', 'mail'),
        join("\n",
             '* First:',
             '> Hi',
             '');
    assert_equals conn_call($tc, 'render', 'forum:[quote=one]Hi[/quote]', 'format', 'news'),
        join("\n",
             '* First:',
             '> Hi',
             '');
    assert_equals conn_call($tc, 'render', 'forum:[quote=unknown]Hi[/quote]', 'format', 'html'),
        join("\n",
             '<div class="attribution">unknown:</div>',
             '<blockquote><p>Hi</p>',
             '</blockquote>',
             '');

    # Test mentions
    assert_equals conn_call($tc, 'render', 'forum:User @two said', 'format', 'html'),
        join("\n",
             '<p>User <a class="userlink" href="http://base/userinfo.cgi/two">Second</a> said</p>',
             '');
    assert_equals conn_call($tc, 'render', 'forum:User @two said', 'format', 'mail'),
        join("\n",
             'User <http://base/userinfo.cgi/two> said',
             '');
    assert_equals conn_call($tc, 'render', 'forum:User @two said', 'format', 'news'),
        join("\n",
             'User <http://base/userinfo.cgi/two> said',
             '');
    assert_equals conn_call($tc, 'render', 'forum:User @unknown said', 'format', 'html'),
        join("\n",
             '<p>User <span class="tfailedlink">user unknown</span> said</p>',
             '');
};
