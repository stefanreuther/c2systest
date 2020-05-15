#!/usr/bin/perl -w
#
#  Test signup.cgi
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Signing up
test 'web/03_signup', sub {
    # Start it
    # user.cgi needs all services
    my $setup = shift;
    my $dbs = setup_add_db($setup);
    my $ufs = setup_add_userfile($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_mailout($setup);
    setup_add_router($setup);
    setup_start_wait($setup);
    c2service::setup_db_init($setup);
    c2service::setup_talk_init($setup);

    # Preparations
    my $dbc = service_connect($dbs);
    my $ufc = service_connect($ufs);
    conn_call($ufc, qw(mkdir u));
    conn_call($ufc, qw(mkdir u/uu));

    # Sign up
    my $cgi = cgi_new($setup, "signup.cgi");
    cgi_set_post_params($cgi,
                        username => "uu",
                        realname => "U. U.",
                        pass1 => "a",
                        pass2 => "a",
                        terms => "read",
                        nerf => "ok");
    cgi_set_ua($cgi, '03_signup');
    my $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);

    # Find cookie
    my $cookie = '';
    foreach (@{$result->{cookies}}) {
        if (/^(session=[^;]*)/) {
            $cookie = $1;
        }
    }
    assert_differs($cookie, '');

    # Must be v3 cookie
    assert_starts_with $cookie, "session=3:";

    # Must be redirect
    assert_starts_with($result->{headers}{status}, 302);
    assert_equals($result->{headers}{location}, '/user.cgi');

    # Using this cookie must be able to successfully retrieve user.cgi
    $cgi = cgi_new($setup, "user.cgi");
    cgi_add_cookie($cgi, $cookie);
    $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);
    assert_starts_with($result->{headers}{status}, 200);

    # Using this cookie must be able to successfully retrieve file.cgi [c2file-server bug, #390]
    $cgi = cgi_new($setup, "file.cgi");
    cgi_add_cookie($cgi, $cookie);
    cgi_set_path($cgi, "/uu/");
    $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);
    assert_starts_with($result->{headers}{status}, 200);

    # Check user Id
    my $uid = conn_call($dbc, qw(get uid:uu));
    assert_equals($uid, 1001);

    # Directory must be owned by this user
    my %stat = @{ conn_call($ufc, qw(stat u/uu)) };
    assert_equals($stat{type}, 'dir');

    %stat = @{ conn_call($ufc, qw(lsperm u/uu)) };
    assert_equals($stat{owner}, $uid);

    # Check configuration via user manager
    my $umc = setup_connect_app($setup, 'user');
    assert_equals conn_call($umc, 'get', $uid, 'screenname'), 'uu';
    assert_equals conn_call($umc, 'get', $uid, 'createua'), '03_signup';
    assert_equals conn_call($umc, 'lookup', 'uu'), $uid;
    assert_equals conn_call($umc, 'name', $uid), 'uu';
    assert_equals conn_call($umc, 'login', 'uu', 'a'), $uid;

    # Check configuration via database
    assert_equals conn_call($dbc, 'hget', "user:$uid:profile", 'screenname'), 'uu';
    assert_equals conn_call($dbc, 'hget', "user:$uid:profile", 'createua'), '03_signup';
    assert_equals conn_call($dbc, 'get', 'uid:uu'), $uid;
    assert_equals conn_call($dbc, 'get', "user:$uid:name"), 'uu';
};
