#!/usr/bin/perl -w
#
#  Speed test for signup.cgi / user.cgi
#
#  20190227    25300 us   (before c2user server)
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Signing up
test 'web/p03_signup', sub {
    # Start it
    # user.cgi needs all services
    my $setup = shift;
    my $dbs = setup_add_db($setup);
    my $ufs = setup_add_userfile($setup);
    setup_add_talk($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_mailout($setup);
    setup_add_router($setup);
    setup_add_usermgr($setup);
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

    # Timing: retrieve user.cgi
    test_timing 'web get user.cgi', sub {
        my $cgi = cgi_new($setup, "user.cgi");
        cgi_add_cookie($cgi, $cookie);
        cgi_run($cgi);
    };
};
