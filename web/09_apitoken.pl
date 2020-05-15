#!/usr/bin/perl -w
#
#  Test API token handling
#

use strict;
use c2systest;
use c2cgitest;

my $PASS_HASH = '1,Z4NHE+IUBLFtmr8yKWYJcg';  # echo -n 'abcpass' | openssl md5 -binary | base64

# Test API token handling.
# A: Log in using user-name and password, obtain an API token.
# E: Data received using API token must be identical to data with user-name and password.
test 'web/09_apitoken/ok', sub {
    my $setup = shift;
    prepare($setup);

    # Login
    my $r1 = setup_post_api($setup, 'api/user.cgi', undef,
                            action => 'whoami',
                            api_user => 'joe',
                            api_password => 'pass');
    assert_equals $r1->{username}, 'joe';
    assert_equals $r1->{screenname}, 'Joe';
    assert_equals $r1->{realname}, 'Joseph';
    assert_differs $r1->{api_token}, '';

    # Use API token
    my $r2 = setup_post_api($setup, 'api/user.cgi', undef,
                            action => 'whoami',
                            api_token => $r1->{api_token});
    assert_list_equals [sort %$r1], [sort %$r2];
};

# Test failing API login.
# A: Log in using user-name and wrong password.
# E: Login must be rejected.
test 'web/09_apitoken/fail', sub {
    my $setup = shift;
    prepare($setup);

    # Login
    assert_throws sub{ setup_post_api($setup, 'api/user.cgi', undef,
                                      action => 'whoami',
                                      api_user => 'joe',
                                      api_password => 'wrong') }, 401;
};

sub prepare {
    my $setup = shift;
    setup_add_service_config($setup, 'www.key', 'xyz');
    setup_add_service_config($setup, 'user.key', 'abc');
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create a user
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(sadd user:all 1001));
    conn_call($dbc, qw(set uid:joe 1001));
    conn_call($dbc, qw(set user:1001:name joe));
    conn_call($dbc, qw(set user:1001:password), $PASS_HASH);
    conn_call($dbc, qw(hmset user:1001:profile realname Joseph screenname Joe));
}
