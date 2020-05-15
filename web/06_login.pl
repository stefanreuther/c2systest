#!/usr/bin/perl -w
#
#  Test login.cgi
#

use strict;
use c2systest;
use c2cgitest;

# Test regular log-in.
# A: use correct username/password.
# E: must respond with redirect to /user.cgi and cookie
test 'web/06_login/normal', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Query => [username => 'joe', pass1 => 'pass']);

    assert !exists $result->{cookies_by_name}{autologin};
    assert_equals  $result->{cookies_by_name}{session}, '3:123456789123456789:joe';
    assert_equals  $result->{headers}{location}, '/user.cgi';
};

# Test regular log-in with auto-login.
# A: use correct username/password, auto-login checked.
# E: must respond with redirect to /user.cgi and cookie
test 'web/06_login/auto', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Query => [username => 'joe', pass1 => 'pass', autologin => 'yes']);

    assert !exists $result->{cookies_by_name}{session};
    assert_equals  $result->{cookies_by_name}{autologin}, '3:123456789123456789:joe';
    assert_equals  $result->{headers}{location}, '/user.cgi';
};

# Test log-in with wrong password.
# A: use wrong username/password.
# E: must respond with HTML
test 'web/06_login/wrong', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Query => [username => 'joe', pass1 => 'wrong']);

    assert !exists $result->{cookies_by_name}{autologin};
    assert !exists $result->{cookies_by_name}{session};
    assert_contains $result->{text}, 'data-logged-in="0"';
};

# Test log-in while logged-in.
# A: use pre-existing valid cookie and username/password.
# E: must respond with redirect to /user.cgi
test 'web/06_login/loggedin', sub {
    my $setup = shift;
    my $result = call_cgi($setup, 
                          Cookies => ["session=3:123456789123456789:joe"],
                          Query => [username => 'joe', pass1 => 'pass']);
    assert !exists $result->{cookies_by_name}{autologin};
    assert_equals  $result->{cookies_by_name}{session}, '3:123456789123456789:joe';
    assert_equals  $result->{headers}{location}, '/user.cgi';
};

# Test log-in with redirection while logged-in.
# A: use pre-existing valid cookie.
# E: must respond with redirect.
test 'web/06_login/redir', sub {
    my $setup = shift;
    my $result = call_cgi($setup, 
                          Cookies => ["session=3:123456789123456789:joe"],
                          Query => [returnto => 'game.cgi']);
    assert !exists $result->{cookies_by_name}{autologin};
    assert !exists $result->{cookies_by_name}{session};
    assert_equals  $result->{headers}{location}, '/game.cgi';
};

# Test failed log-in with auto-login checked.
# (This used to generate obsolescent HTML.)
# A: provide partially-completed login form.
# E: must respond with correct partially-filled form.
test 'web/06_login/partial', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Query => [username => 'joe', autologin => 'yes']);
    assert_starts_with $result->{headers}{status}, 200;
    assert !exists $result->{cookies_by_name}{autologin};
    assert !exists $result->{cookies_by_name}{session};
    assert_contains $result->{text}, 'value="joe"';
};

# Test regular log-in with expired cookie.
# A: use correct username/password.
# E: must respond with redirect to /user.cgi and cookie
test 'web/06_login/expired', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Query => [username => 'joe', pass1 => 'pass'], Until => 1);

    assert !exists $result->{cookies_by_name}{autologin};
    assert_starts_with $result->{cookies_by_name}{session}, '3:';
    assert_equals $result->{headers}{location}, '/user.cgi';
};

# call_cgi($setup, opts=>value....)
sub call_cgi {
    my $setup = shift;
    my %opts = @_;

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
    conn_call($dbc, qw(set user:1001:password), '1,Z4NHE+IUBLFtmr8yKWYJcg'); # echo -n 'abcpass' | openssl md5 -binary | base64
    conn_call($dbc, qw(hmset user:1001:profile realname Joseph screenname Joe));

    # Create tokens
    my $end = $opts{Until} || 1000000000; # Year 3871 problem
    conn_call($dbc, qw(hmset token:t:123456789123456789 user 1001 type login until), $end);
    conn_call($dbc, qw(sadd token:all 123456789123456789));
    conn_call($dbc, qw(sadd user:1001:tokens:login 123456789123456789));

    my $cgi = cgi_new($setup, "login.cgi");
    cgi_add_cookie($cgi, @{$opts{Cookies}})
        if $opts{Cookies};
    cgi_set_get_params($cgi, @{$opts{Query}})
        if $opts{Query};
    my $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);

    $result;
}
