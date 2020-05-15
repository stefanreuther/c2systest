#!/usr/bin/perl -w
#
#  Test basic token management
#
use strict;
use c2systest;

# Test basic token management (unit-test equivalent).
# A: create some tokens
# E: tokens created with different parameters need be different; need to be retrievable
test 'user/50_usertoken/simple', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # Create a token
    my $a = conn_call($umc, qw(maketoken a login));
    assert_differs $a, '';

    # Requesting another token of the same type must produce the same thing
    my $b = conn_call($umc, qw(maketoken a login));
    assert_equals $a, $b;

    # Requesting a different type must produce a different token
    my $c = conn_call($umc, qw(maketoken a api));
    assert_differs $c, '';
    assert_differs $a, $c;

    # Requesting for a different user must produce a different token
    my $d = conn_call($umc, qw(maketoken b login));
    assert_differs $d, '';
    assert_differs $a, $d;
    assert_differs $c, $d;

    # Retrieve token information
    my %info = conn_call_list($umc, 'checktoken', $a);
    assert_equals $info{user}, 'a';
    assert_equals $info{type}, 'login';
    assert !defined $info{new};

    # Retrieve token with wrong type
    assert_throws sub{ conn_call($umc, 'checktoken', $a, 'type', 'api') }, 410;

    # Retrieve wrong token
    assert_throws sub{ conn_call($umc, 'checktoken', "$a$c$d") }, 410;
};

# TestServerUserUserToken::testClearToken
test 'user/50_usertoken/simple', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # Create some tokens
    my $a = conn_call($umc, 'maketoken', 'x', 'login');
    my $b = conn_call($umc, 'maketoken', 'x', 'api');
    conn_call($umc, 'checktoken', $a);
    conn_call($umc, 'checktoken', $b);

    # Removing other users' tokens does not affect us
    conn_call($umc, 'resettoken', 'y', 'api');
    conn_call($umc, 'checktoken', $a);
    conn_call($umc, 'checktoken', $b);

    # Removing one token does not affect the other
    conn_call($umc, 'resettoken', 'x', 'api');
    conn_call($umc, 'checktoken', $a);
    assert_throws sub{ conn_call($umc, 'checktoken', $b) }, 410;

    # We can remove unknown token types
    conn_call($umc, 'resettoken', 'x', 'other');
};
