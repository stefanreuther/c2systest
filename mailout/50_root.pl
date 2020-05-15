#!/usr/bin/perl -w
#
#  Mailout Root unit test equivalents
#
use c2systest;
use strict;

# TestServerMailoutRoot::testGetUserStatus: Test getUserStatus(), regular case.
test 'mailout/50_root/status/normal', sub {
    my $setup = shift;
    setup_add_mailout($setup);
    setup_add_db($setup);
    setup_start_wait($setup);

    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hset user:1009:profile email ad@re.ss));
    conn_call($db, qw(hmset email:ad@re.ss:status status/1009 c expire/1009 99999999));

    my $mc = setup_connect_app($setup, 'mailout');
    my %info = conn_call_list($mc, qw(status 1009));
    assert_equals $info{address}, 'ad@re.ss';
    assert_equals $info{status}, 'c';
};

# TestServerMailoutRoot::testGetUserStatusEmpty: Test getUserStatus(), empty database (aka user has no email).
test 'mailout/50_root/status/empty', sub {
    my $setup = shift;
    setup_add_mailout($setup);
    setup_add_db($setup);
    setup_start_wait($setup);

    my $mc = setup_connect_app($setup, 'mailout');
    my %info = conn_call_list($mc, qw(status 1009));
    assert_equals $info{address}, '';
    assert_equals $info{status}, '';
};

# TestServerMailoutRoot::testGetUserStatusUnconfirmed: Test getUserStatus(), half-empty database (aka user created but not yet requested).
test 'mailout/50_root/status/unconfirmed', sub {
    my $setup = shift;
    setup_add_mailout($setup);
    setup_add_db($setup);
    setup_start_wait($setup);

    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hset user:1009:profile email ad@re.ss));

    my $mc = setup_connect_app($setup, 'mailout');
    my %info = conn_call_list($mc, qw(status 1009));
    assert_equals $info{address}, 'ad@re.ss';
    assert_equals $info{status}, 'u';
};
