#!/usr/bin/perl -w
#
#  Test basic user management
#
use strict;
use c2systest;

# TestServerUserUserData::testIt: basic functionality test
test 'user/50_userdata/basic', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);
    my $umc = setup_connect_app($setup, 'user');

    # No data stored
    assert_equals conn_call($umc, qw(uget u k)), "";

    # Store some data
    conn_call($umc, qw(uset u k  one));
    conn_call($umc, qw(uset u k2 two));

    # Retrieve data
    assert_equals conn_call($umc, qw(uget u k)),  "one";
    assert_equals conn_call($umc, qw(uget u k2)), "two";
};

# TestServerUserUserData::testExpire: Test expiration upon exceeded size.
test 'user/50_userdata/expire', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.data.maxtotalsize', 100);
    setup_start_wait($setup);
    my $umc = setup_connect_app($setup, 'user');

    # Set two values. These should take a total of 2*(2*1 + 43) = 90 bytes.
    my $value = 'x' x 43;
    conn_call($umc, 'uset', 'u', 'a', $value);
    conn_call($umc, 'uset', 'u', 'b', $value);

    assert_equals conn_call($umc, qw(uget u a)), $value;
    assert_equals conn_call($umc, qw(uget u b)), $value;

    # Set another value. This should expire 'a'
    conn_call($umc, 'uset', 'u', 'c', $value);
    assert_equals conn_call($umc, qw(uget u a)), '';
    assert_equals conn_call($umc, qw(uget u b)), $value;
    assert_equals conn_call($umc, qw(uget u c)), $value;

    # Set 'b' again, then another value. This should expire 'c'
    conn_call($umc, 'uset', 'u', 'b', $value);
    conn_call($umc, 'uset', 'u', 'd', $value);
    assert_equals conn_call($umc, qw(uget u a)), '';
    assert_equals conn_call($umc, qw(uget u b)), $value;
    assert_equals conn_call($umc, qw(uget u c)), '';
    assert_equals conn_call($umc, qw(uget u d)), $value;

    # Set value on another user. This should not affect this one.
    conn_call($umc, 'uset', 'v', 'a', $value);
    assert_equals conn_call($umc, qw(uget u a)), '';
    assert_equals conn_call($umc, qw(uget u b)), $value;
    assert_equals conn_call($umc, qw(uget u c)), '';
    assert_equals conn_call($umc, qw(uget u d)), $value;
    assert_equals conn_call($umc, qw(uget v a)), $value;
};

# TestServerUserUserData::testExpire2: Test expiration upon exceeded size.
test 'user/50_userdata/expire2', sub {
    # Environment
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.data.maxtotalsize', 100);
    setup_start_wait($setup);
    my $umc = setup_connect_app($setup, 'user');

    # Set three values. These should take a total of 2*(2*1 + 28) = 90 bytes.
    my $value = 'x' x 28;
    conn_call($umc, 'uset', 'u', 'a', $value);
    conn_call($umc, 'uset', 'u', 'b', $value);
    conn_call($umc, 'uset', 'u', 'c', $value);

    assert_equals conn_call($umc, 'uget', 'u', 'a'), $value;
    assert_equals conn_call($umc, 'uget', 'u', 'b'), $value;
    assert_equals conn_call($umc, 'uget', 'u', 'c'), $value;

    # Set 'b' to empty, add two values. This should expire 'a'.
    conn_call($umc, 'uset', 'u', 'b', '');
    conn_call($umc, 'uset', 'u', 'd', $value);
    conn_call($umc, 'uset', 'u', 'e', $value);

    assert_equals conn_call($umc, 'uget', 'u', 'a'), '';
    assert_equals conn_call($umc, 'uget', 'u', 'b'), '';
    assert_equals conn_call($umc, 'uget', 'u', 'c'), $value;
    assert_equals conn_call($umc, 'uget', 'u', 'd'), $value;
    assert_equals conn_call($umc, 'uget', 'u', 'e'), $value;
};

# TestServerUserUserData::testError: Test error cases.
test 'user/50_userdata/error', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_add_service_config($setup, 'user.data.maxkeysize', 10);
    setup_add_service_config($setup, 'user.data.maxvaluesize', 20);
    setup_start_wait($setup);
    my $umc = setup_connect_app($setup, 'user');

    # Base case (valid)
    conn_call($umc, 'uset', 'u', 'aaaaaaaaaa', 'bbbbbbbbbbbbbbbbbbbb');

    # Invalid keys
    assert_throws sub{ conn_call($umc, 'uset', 'u', '', '') }, 400;
    assert_throws sub{ conn_call($umc, 'uset', 'u', "\x81", '') }, 400;
    assert_throws sub{ conn_call($umc, 'uset', 'u', "\n", '') }, 400;
    assert_throws sub{ conn_call($umc, 'uset', 'u', "aaaaaaaaaaa", '') }, 400;

    # Invalid values
    assert_throws sub{ conn_call($umc, 'uset', 'u', "a", "xxxxxxxxxxxxxxxxxxxxx") }, 400;
};
