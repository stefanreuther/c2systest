#!/usr/bin/perl -w
#
#  NNTP: test commands while not logged in
#
use strict;
use c2systest;

# Test login
test 'nntp/02_lockout', sub {
    # Start
    my $setup = shift;
    setup_add_service_config($setup, 'user.key', 'xyz');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_add_nntp($setup);
    setup_start_wait($setup);

    # Talk
    my $nnc = setup_connect_app($setup, 'nntp');

    # - Read banner
    assert_differs conn_interact($nnc, undef), '';

    # article, body, head, stat
    assert_starts_with conn_interact($nnc, 'article <a@b>'), 480;
    assert_starts_with conn_interact($nnc, 'head <a@b>'), 480;
    assert_starts_with conn_interact($nnc, 'body <a@b>'), 480;
    assert_starts_with conn_interact($nnc, 'stat <a@b>'), 480;

    # group, listgroup
    assert_starts_with conn_interact($nnc, 'group ng.name'), 480;
    assert_starts_with conn_interact($nnc, 'listgroup ng.name'), 480;

    # list
    assert_starts_with conn_interact($nnc, 'list'), 480;
    assert_starts_with conn_interact($nnc, 'list active'), 480;
    assert_starts_with conn_interact($nnc, 'list newsgroups'), 480;
    assert_starts_with conn_interact($nnc, 'list subscriptions'), 480;

    # over
    assert_starts_with conn_interact($nnc, 'group 1-2'), 480;
};
