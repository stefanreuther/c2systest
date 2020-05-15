#!/usr/bin/perl -w
#
#  Talk API performance
#
#  20190320   29500 us (classic)
#  20190320   28900 us (using 'user' server)
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

test 'web/p25_talkapi', sub {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    my $tc = setup_connect_app($setup, 'talk');
    my $uc = setup_connect_app($setup, 'user');

    # Create a user, forum, post
    my $u1 = c2service::setup_add_user($setup, 'joe');
    my $f1 = conn_call($tc, 'forumadd', 'name', 'Forum One', 'readperm', 'all');
    my $p1 = conn_call($tc, 'postnew', $f1, 'Subject One', 'text:Text One', 'user', $u1);
    my $token = setup_make_api_token($setup, $u1);

    # Performance
    test_timing 'web talk api poststat', sub {
        my $cgi = cgi_new($setup, 'api/talk.cgi');
        cgi_set_post_params($cgi, api_token => $token, action => 'poststat', mid => $p1);

        my $result = cgi_run($cgi);
        assert_starts_with $result->{headers}{"content-type"}, "text/json";

        # Process result
        my $r = json_parse($result->{text});
        assert_equals $r->{result}, 1;
        assert_equals $r->{author}, 'joe';
        assert_equals $r->{subject}, 'Subject One';
        assert_equals $r->{parent}, 0;
    };
};
