#!/usr/bin/perl -w
#
#  NNTP: test login
#
use strict;
use c2systest;

# Test login
test 'nntp/01_login', sub {
    # Start
    my $setup = shift;
    setup_add_service_config($setup, 'user.key', 'xyz');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_add_nntp($setup);
    setup_start_wait($setup);

    # Preload database
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'set', 'user:1009:password', '1,52YluJAXWKqqhVThh22cNw');
    conn_call($db, 'set', 'uid:a_b', '1009');

    # Talk
    my $nnc = setup_connect_app($setup, 'nntp');

    # - Read banner
    assert_differs conn_interact($nnc, undef), '';

    # - Check help command (why not)
    assert_differs conn_interact($nnc, 'help', '^1'), '';

    # - Login
    assert_starts_with conn_interact($nnc, 'authinfo user a_b'), '381';
    assert_starts_with conn_interact($nnc, 'authinfo pass z'), '281';

    # - Check LIST ACTIVE. We don't have any groups.
    assert_equals conn_interact($nnc, 'list active', '^215'), '';
};
