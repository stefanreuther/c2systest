#!/usr/bin/perl -w
#
#  Password change
#

use strict;
use c2systest;
use c2cgitest;

# Test log in using session cookies.
# A: Create user using signup.cgi, log them in. Change password.
# E: Cookies must be equivalent. Password change must invalidate cookies.
test 'web/11_chpw/session', sub {
    my $setup = shift;
    do_test($setup, 'session', 'autologin');
};

# Test log in using autologin cookies.
# A: Create user using signup.cgi, log them in with auto-login enabled. Change password.
# E: Cookies must be equivalent. Password change must invalidate cookies.
test 'web/11_chpw/auto', sub {
    my $setup = shift;
    do_test($setup, 'autologin', 'session');
};


# Common part of test
sub do_test {
    my ($setup, $active, $other) = @_;

    setup_add_service_config($setup, 'www.key', 'xyz');
    setup_add_service_config($setup, 'user.key', 'abc');
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Prepare
    conn_call(setup_connect_app($setup, 'file'), qw(mkdir u));

    # Create user
    my $signup = cgi_new($setup, 'signup.cgi');
    cgi_set_post_params($signup, username => 'fred', realname => 'Fred Flintstone', pass1 => 'w1lma', pass2 => 'w1lma', terms => 'read', nerf => "ok");

    my $signup_result = cgi_run($signup);
    cgi_verify_result($signup, $signup_result);
    assert  exists $signup_result->{cookies_by_name}{session};
    assert !exists $signup_result->{cookies_by_name}{autologin};
    my $signup_cookie = $signup_result->{cookies_by_name}{session};

    # Log in
    my $login = cgi_new($setup, 'login.cgi');
    my @args = (username => 'fred', pass1 => 'w1lma');
    push @args, (autologin => 'yes')
        if $active eq 'autologin';
    cgi_set_post_params($login, @args);

    my $login_result = cgi_run($login);
    cgi_verify_result($login, $login_result);
    assert  exists $login_result->{cookies_by_name}{$active};
    assert !exists $login_result->{cookies_by_name}{$other};
    my $login_cookie = $login_result->{cookies_by_name}{$active};

    # Cross-check
    assert_equals $login_cookie, $signup_cookie;

    # Change password
    my $chpw = cgi_new($setup, 'settings.cgi');
    cgi_set_post_params($chpw, action => 'save_password', pass1 => 'b4rn3y', pass2 => 'b4rn3y');
    cgi_add_cookie($chpw, "$active=$login_cookie");

    my $chpw_result = cgi_run($chpw);
    assert  exists $chpw_result->{cookies_by_name}{$active};
    assert !exists $chpw_result->{cookies_by_name}{$other};
    my $chpw_cookie = $chpw_result->{cookies_by_name}{$active};

    # Cookie must be new
    assert_differs $chpw_cookie, $login_cookie;

    # New cookie must be usable, old one must not
    my $new = cgi_new($setup, 'index.cgi');
    cgi_add_cookie($new, "$active=$chpw_cookie");
    my $new_result = cgi_run($new);
    assert_contains $new_result->{text}, 'data-logged-in="1"';

    my $old = cgi_new($setup, 'index.cgi');
    cgi_add_cookie($old, "$active=$login_cookie");
    my $old_result = cgi_run($old);
    assert_contains $old_result->{text}, 'data-logged-in="0"';

    # Log-in using new password must succeed and produce usable cookie
    my $login2 = cgi_new($setup, 'login.cgi');
    cgi_set_post_params($login2, username => 'fred', pass1 => 'b4rn3y');
    my $login2_result = cgi_run($login2);
    assert exists $login2_result->{cookies_by_name}{session};
    assert_starts_with $login2_result->{headers}{status}, 302;
    assert_equals $login2_result->{headers}{location}, '/user.cgi';
    assert_equals $login2_result->{cookies_by_name}{session}, $chpw_cookie;
};
