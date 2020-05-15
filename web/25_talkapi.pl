#!/usr/bin/perl -w
#
#  Test talk API
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

test 'web/25_talkapi', sub {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create a few users
    my $u1 = c2service::setup_add_user($setup, 'joe');
    my $u2 = c2service::setup_add_user($setup, 'fred');
    my $u3 = c2service::setup_add_user($setup, 'barney');

    # Cookies
    my $c1 = setup_make_cookie($setup, $u1);
    my $c2 = setup_make_cookie($setup, $u2);
    my $c3 = setup_make_cookie($setup, $u3);

    # Create some forums
    my $tc = setup_connect_app($setup, 'talk');
    my $f1 = conn_call($tc, 'forumadd', 'name', 'Forum One', 'readperm', 'all');
    my $f2 = conn_call($tc, 'forumadd', 'name', 'Forum Two', 'readperm', 'all');
    my $p1 = conn_call($tc, 'postnew',   $f1, 'Subject One',       'text:Text One',   'user', $u1);
    my $p2 = conn_call($tc, 'postreply', $p1, 'Re: Subject One',   'text:Text Two',   'user', $u2);
    my $p3 = conn_call($tc, 'postnew',   $f2, 'Subject Three',     'text:Text Three', 'user', $u3);
    my $p4 = conn_call($tc, 'postreply', $p3, 'Re: Subject Three', 'text:Text Four',  'user', $u1);

    # Test 'postrender'
    my $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c1, action => 'postrender', mid => $p1);
    assert_equals $r->{result}, 1;
    assert_equals $r->{text}, "<p>Text One</p>\n";

    # Test 'postmrender'
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c1, action => 'postmrender', mids => "$p1,$p2");
    assert_equals $r->{result}, 1;
    assert_equals $r->{reply}[0], "<p>Text One</p>\n";
    assert_equals $r->{reply}[1], "<p>Text Two</p>\n";

    # Test 'poststat'
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c1, action => 'poststat', mid => $p1);
    assert_equals $r->{result}, 1;
    assert_equals $r->{author}, 'joe';
    assert_equals $r->{subject}, 'Subject One';
    assert_equals $r->{parent}, 0;

    # Test 'postmstat'
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c1, action => 'postmstat', mids => "$p1,$p2,$p3");
    assert_equals $r->{result}, 1;
    assert_equals $r->{reply}[0]{author}, 'joe';
    assert_equals $r->{reply}[0]{subject}, 'Subject One';
    assert_equals $r->{reply}[0]{parent}, 0;
    assert_equals $r->{reply}[1]{author}, 'fred';
    assert_equals $r->{reply}[1]{subject}, 'Re: Subject One';
    assert_equals $r->{reply}[1]{parent}, $p1;
    assert_equals $r->{reply}[2]{author}, 'barney';
    assert_equals $r->{reply}[2]{subject}, 'Subject Three';
    assert_equals $r->{reply}[2]{parent}, 0;
    assert_equals $r->{reply}[0]{thread}, $r->{reply}[1]{thread};

    # Test 'forumlspost'
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c1, action => 'forumlspost', fid => $f1, sort => 'author');
    assert_equals $r->{result}, 1;
    assert_list_equals $r->{reply}, [$p1,$p2];

    # Test 'userlsposted'
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c1, action => 'userlsposted', user => 'fred');
    assert_equals $r->{result}, 1;
    assert_list_equals $r->{reply}, [$p2];

    # Test 'userlsposted' with non-standard user name
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c3, action => 'userlsposted', user => '--Joe--');
    assert_equals $r->{result}, 1;
    assert_list_equals $r->{reply}, [$p1,$p4];

    # Test 'userlsposted' with sort-by-subject
    $r = setup_post_api($setup, 'api/talk.cgi', undef, api_token => $c3, action => 'userlsposted', user => 'joe', sort => 'subject');
    assert_equals $r->{result}, 1;
    assert_list_equals $r->{reply}, [$p4,$p1];
};
