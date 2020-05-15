#!/usr/bin/perl -w
#
#  Test basic token management
#

use strict;
use c2systest;

test 'user/01_token', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # FIXME: add user

    # Create tokens
    my $token  = conn_call($umc, qw(maketoken 1001 login));
    my $token2 = conn_call($umc, qw(maketoken 1001 login));
    my $token3 = conn_call($umc, qw(maketoken 1001 api));
    assert_equals $token, $token2;
    assert_differs $token, $token3;

    # Tokens need to be resolvable
    my %result = conn_call_list($umc, 'checktoken', $token);
    assert_equals $result{user}, 1001;
    assert_equals $result{type}, 'login';

    %result = conn_call_list($umc, 'checktoken', $token3);
    assert_equals $result{user}, 1001;
    assert_equals $result{type}, 'api';
};
