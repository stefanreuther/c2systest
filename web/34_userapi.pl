#!/usr/bin/perl -w
use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test whoami for not-logged-in user.
# A: invoke API without any token
# E: should return not-logged-in.
test 'web/34_userapi/whoami/anon', sub {
    my $setup = shift;
    prepare($setup);

    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'whoami');

    assert_equals $result->{result}, 1;
    assert_equals $result->{loggedin}, 0;
};

# Test whoami with username/password.
# A: invoke API with username/password.
# E: should return logged-in and a functioning API token.
test 'web/34_userapi/whoami/pass', sub {
    my $setup = shift;
    prepare($setup);

    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'set', 1001, realname => 'Fred Flintstone', infotown => 'Bedrock');

    # Username/password
    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'whoami', api_user => 'fred', api_password => 'secret');
    assert_equals $result->{result}, 1;
    assert_equals $result->{loggedin}, 1;
    assert_equals $result->{username}, 'fred';
    assert_equals $result->{realname}, 'Fred Flintstone';
    assert_equals $result->{screenname}, 'fred';

    # Token
    my $result2 = setup_post_api($setup, 'api/user.cgi', undef, action => 'whoami', api_token => $result->{api_token});
    assert_equals $result2->{result}, 1;
    assert_equals $result2->{loggedin}, 1;
    assert_equals $result2->{username}, 'fred';
    assert_equals $result2->{realname}, 'Fred Flintstone';
    assert_equals $result2->{screenname}, 'fred';
};

# Test whoami with cookie.
# A: invoke API with generated cookie.
# E: should return logged-in and a functioning API token.
test 'web/34_userapi/whoami/cookie', sub {
    my $setup = shift;
    prepare($setup);

    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'set', 1001, realname => 'Fred Flintstone', infotown => 'Bedrock');

    # Cookie
    my $cookie = setup_make_cookie($setup, 1001);
    my $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'whoami');
    assert_equals $result->{result}, 1;
    assert_equals $result->{loggedin}, 1;
    assert_equals $result->{username}, 'fred';
    assert_equals $result->{realname}, 'Fred Flintstone';
    assert_equals $result->{screenname}, 'fred';

    # Token
    my $result2 = setup_post_api($setup, 'api/user.cgi', undef, action => 'whoami', api_token => $result->{api_token});
    assert_equals $result2->{result}, 1;
    assert_equals $result2->{loggedin}, 1;
    assert_equals $result2->{username}, 'fred';
    assert_equals $result2->{realname}, 'Fred Flintstone';
    assert_equals $result2->{screenname}, 'fred';
};

# Test profile retrieval, some regular cases.
# A: create normal profile. Retrieve fred's user profile as fred, anonymous, and other user.
# E: profile returned correctly with correct content
test 'web/34_userapi/profile/normal', sub {
    my $setup = shift;
    prepare($setup);

    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'set', 1001, realname => 'Fred Flintstone', infotown => 'Bedrock', email => 'fred@flint.stone', infoemailflag => 1);

    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:fred@flint.stone:status', 'status/1001', 'c');

    # With cookie
    my $cookie = setup_make_cookie($setup, 1001);
    my $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'profile', user => 'fred');
    assert_equals $result->{result}, 1;
    assert_equals $result->{realname}, 'Fred Flintstone';
    assert_equals $result->{infotown}, 'Bedrock';
    assert_equals $result->{infoemailflag}, 1;
    assert_equals $result->{email}, 'fred@flint.stone';

    # Without cookie
    my $result2 = setup_post_api($setup, 'api/user.cgi', undef, action => 'profile', user => 'fred');
    assert_equals $result2->{result}, 1;
    assert_equals $result2->{infotown}, 'Bedrock';
    assert !exists $result2->{realname};               # inforealnameflag not set by default
    assert !exists $result2->{email};                  # set, but not available to anonymous users

    # With other-user cookie
    my $cookie3 = setup_make_cookie($setup, 1020);
    my $result3 = setup_post_api($setup, 'api/user.cgi', $cookie3, action => 'profile', user => 'fred');
    assert_equals $result3->{result}, 1;
    assert_equals $result3->{infotown}, 'Bedrock';
    assert_equals $result3->{email}, 'fred@flint.stone';
    assert !exists $result3->{realname};               # inforealnameflag not set by default
};

# Test profile retrieval, unconfirmed email.
# A: Create profile with unconfirmed email. Retrieve fred's user profile as fred, anonymous, and other user.
# E: profile returned but does not contain email address
test 'web/34_userapi/profile/unconf_mail', sub {
    my $setup = shift;
    prepare($setup);

    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'set', 1001, realname => 'Fred Flintstone', infotown => 'Bedrock', email => 'fred@flint.stone', infoemailflag => 1);

    # With cookie
    my $cookie = setup_make_cookie($setup, 1001);
    my $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'profile', user => 'fred');
    assert_equals $result->{result}, 1;
    assert_equals $result->{realname}, 'Fred Flintstone';
    assert_equals $result->{infotown}, 'Bedrock';
    assert_equals $result->{infoemailflag}, 1;
    assert !exists $result->{email};                   # not confirmed

    # With other-user cookie
    my $cookie3 = setup_make_cookie($setup, 1020);
    my $result3 = setup_post_api($setup, 'api/user.cgi', $cookie3, action => 'profile', user => 'fred');
    assert_equals $result3->{result}, 1;
    assert_equals $result3->{infotown}, 'Bedrock';
    assert !exists $result3->{email};                  # not confirmed
    assert !exists $result3->{realname};               # inforealnameflag not set by default
};

# Test profile retrieval, real-name flag.
# A: create profile, set inforealnameflag. Retrieve user profile as fred, anonymous, and other user.
# E: profile returned correctly with real name
test 'web/34_userapi/profile/realname', sub {
    my $setup = shift;
    prepare($setup);

    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'set', 1001, realname => 'Fred Flintstone', infotown => 'Bedrock', inforealnameflag => 1);

    # With cookie
    my $cookie = setup_make_cookie($setup, 1001);
    my $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'profile', user => 'fred');
    assert_equals $result->{result}, 1;
    assert_equals $result->{realname}, 'Fred Flintstone';
    assert_equals $result->{infotown}, 'Bedrock';

    # Without cookie
    my $result2 = setup_post_api($setup, 'api/user.cgi', undef, action => 'profile', user => 'fred');
    assert_equals $result2->{result}, 1;
    assert_equals $result2->{infotown}, 'Bedrock';
    assert_equals $result2->{realname}, 'Fred Flintstone';

    # With other-user cookie
    my $cookie3 = setup_make_cookie($setup, 1020);
    my $result3 = setup_post_api($setup, 'api/user.cgi', $cookie3, action => 'profile', user => 'fred');
    assert_equals $result3->{result}, 1;
    assert_equals $result3->{infotown}, 'Bedrock';
    assert_equals $result3->{realname}, 'Fred Flintstone';
};

# Test profile retrieval, wrong user name.
# A: create profile, set inforealnameflag. Retrieve user profile as fred, anonymous, and other user.
# E: profile returned correctly with real name
test 'web/34_userapi/profile/wrong', sub {
    my $setup = shift;
    prepare($setup);

    # With cookie
    my $cookie = setup_make_cookie($setup, 1001);
    assert_throws sub{ setup_post_api($setup, 'api/user.cgi', $cookie, action => 'profile', user => 'ottilie') }, 404;
};

# Test multi-profile retrieval.
test 'web/34_userapi/profile/unconf_mail', sub {
    my $setup = shift;
    prepare($setup);

    # Create some more users
    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'adduser', 'Doris', 'x');
    conn_call($uc, 'adduser', 'Laura', 'x');
    conn_call($uc, 'adduser', 'Eric', 'x');
    conn_call($uc, 'adduser', 'Timmy', 'x');

    # Query them
    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'mprofile', users => 'FRED,Doris,eric,TImmY');
    assert_equals $result->{result}, 1;
    assert_equals $result->{reply}[0]{screenname}, 'fred';
    assert_equals $result->{reply}[1]{screenname}, 'Doris';
    assert_equals $result->{reply}[2]{screenname}, 'Eric';
    assert_equals $result->{reply}[3]{screenname}, 'Timmy';
};



sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    c2service::setup_db_init($setup);

    my $uc = setup_connect_app($setup, 'user');
    my $id = conn_call($uc, 'adduser', 'fred', 'secret');
    assert_equals $id, 1001;
}
