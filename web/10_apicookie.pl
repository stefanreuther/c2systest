#!/usr/bin/perl -w
#
#  Test API cookie handling
#

use strict;
use c2systest;
use c2cgitest;

my $PASS_HASH = '1,Z4NHE+IUBLFtmr8yKWYJcg';  # echo -n 'abcpass' | openssl md5 -binary | base64

# Test API cookie handling.
# A: Log in using user-name and password, obtain a cookie.
# E: Cookie must be same as produced by regular log-in flow. Data received using cookie must be identical to data with user-name and password.
test 'web/10_apicookie', sub {
    my $setup = shift;
    
    setup_add_service_config($setup, 'www.key', 'xyz');
    setup_add_service_config($setup, 'user.key', 'abc');
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create a user
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(sadd user:all 1001));
    conn_call($dbc, qw(set uid:joe 1001));
    conn_call($dbc, qw(set user:1001:name joe));
    conn_call($dbc, qw(set user:1001:password), $PASS_HASH);
    conn_call($dbc, qw(hmset user:1001:profile realname Joseph screenname Joe));

    # Login using api_mode=1. Must produce a cookie.
    my $c1 = cgi_new($setup, 'api/user.cgi');
    cgi_set_get_params($c1, action => 'whoami', api_user => 'joe', api_password => 'pass', api_mode => 1);

    my $r1 = cgi_run($c1);
    assert_starts_with $r1->{headers}{'content-type'}, 'text/json';
    assert_differs $r1->{cookies_by_name}{session}, '';

    # Same thing with login.
    my $c2 = cgi_new($setup, 'login.cgi');
    cgi_set_post_params($c2, username => 'joe', pass1 => 'pass');

    my $r2 = cgi_run($c2);
    assert_starts_with $r2->{headers}{status}, 302;
    assert_differs $r2->{cookies_by_name}{session}, '';

    # Must be able to use cookie to retrieve stuff
    my $c3 = cgi_new($setup, 'api/user.cgi');
    cgi_set_get_params($c3, action => 'whoami');
    cgi_add_cookie($c3, "session=$r2->{cookies_by_name}{session}");

    my $r3 = cgi_run($c3);
    assert_starts_with $r3->{headers}{'content-type'}, 'text/json';
    assert !$r3->{cookies_by_name}{session};

    # Consistency checks: cookies must be the same, same result in both API calls
    assert_equals $r1->{cookies_by_name}{session}, $r2->{cookies_by_name}{session};
    assert_equals $r1->{text}, $r3->{text};
};
