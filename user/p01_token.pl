#!/usr/bin/perl -w
#
#  Performance test for token management
#

use strict;
use c2systest;

test 'user/p01_token', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    my $umc = setup_connect_app($setup, 'user');

    # FIXME: add user

    my $token = conn_call($umc, qw(maketoken 1001 login));
    test_timing 'user maketoken', sub {
        conn_call($umc, 'checktoken', $token);
    };
};
