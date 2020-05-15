#!/usr/bin/perl -w
#
#  Test general (page-independant) cookie management
#
#  As of 20191121, "v2" cookies are no longer supported; tests have been commented out.
#

use strict;
use c2systest;
use c2cgitest;

# Test standard behaviour.
# A: present a v3 session cookie.
# E: must be logged in, no more cookie traffic.
test 'web/05_cookie/3_ok', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=3:123456789123456789:joe"]);
    assert_contains $result->{text}, 'data-logged-in="1"';
    assert_contains $result->{text}, 'data-user="joe"';
    assert !exists $result->{cookies_by_name}{session};
    assert !exists $result->{cookies_by_name}{autologin};
    assert $result->{text} !~ /User manager is down/;

    # Verify HTML
    my $html = html_verify('web/05_cookie', $result->{text});
    assert exists $html->{links}{"/logout.cgi"};
};

# Test upgrade.
# A: present a v2 session cookie.
# E: must be logged in and receive a v3 cookie.
test 'web/05_cookie/2_upgrade', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=2:1001,joe,,apmRvfeB1FPOGUBK9a3Ayw"]);

    assert_contains $result->{text}, 'data-logged-in="0"';

    # assert_contains $result->{text}, 'data-logged-in="1"';
    # assert_contains $result->{text}, 'data-user="joe"';
    # assert_equals $result->{cookies_by_name}{session}, "3:123456789123456789:joe";
    # assert !exists $result->{cookies_by_name}{autologin};
    # assert $result->{text} !~ /User manager is down/;
};

# Test upgrade with two cookies.
# A: present a v2 session cookie and an autologin cookie.
# E: must be logged in and receive a v3 cookie.
test 'web/05_cookie/2_upgrade_both', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=2:1001,joe,,apmRvfeB1FPOGUBK9a3Ayw", "autologin=2:1001,joe,,apmRvfeB1FPOGUBK9a3Ayw"]);

    assert_contains $result->{text}, 'data-logged-in="0"';

    # assert_contains $result->{text}, 'data-logged-in="1"';
    # assert_contains $result->{text}, 'data-user="joe"';
    # assert_equals $result->{cookies_by_name}{autologin}, "3:123456789123456789:joe";
    # assert_equals $result->{cookies_by_name}{session}, "";
    # assert $result->{text} !~ /User manager is down/;
};

# Test unknown cookie.
# A: present an unknown v3 cookie.
# E: must NOT be logged in. Note that we do not explicitly delete the cookie.
test 'web/05_cookie/3_bad', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=3:123456789xxxxxxxxx:joe"]);
    assert_contains $result->{text}, 'data-logged-in="0"';
    assert !exists $result->{cookies_by_name}{session};
    assert !exists $result->{cookies_by_name}{autologin};

    # Verify HTML
    my $html = html_verify('web/05_cookie', $result->{text});
    assert exists $html->{links}{"/login.cgi"};
    assert $result->{text} !~ /User manager is down/;
};

# Test unknown v2 cookie.
# A: present an unknown v2 cookie.
# E: must NOT be logged in. Cookie is deleted.
test 'web/05_cookie/2_bad', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=2:1001,joe,,apmRvfeB1XXXXXBK9a3Ayw"]);

    assert_contains $result->{text}, 'data-logged-in="0"';

    # assert_contains $result->{text}, 'data-logged-in="0"';
    # assert !exists $result->{cookies_by_name}{session};
    # assert !exists $result->{cookies_by_name}{autologin};
    # assert $result->{text} !~ /User manager is down/;
};

# Test auto-login with v3 cookie.
# A: present a v3 auto-login cookie.
# E: must be logged in, no more cookie traffic. We do no longer copy cookies.
test 'web/05_cookie/3_auto', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["autologin=3:123456789123456789:joe"]);
    assert_contains $result->{text}, 'data-logged-in="1"';
    assert_contains $result->{text}, 'data-user="joe"';
    assert !exists $result->{cookies_by_name}{session};
    assert !exists $result->{cookies_by_name}{autologin};
    assert $result->{text} !~ /User manager is down/;
};

# Test auto-login with v2 cookie.
# A: present a v2 auto-login cookie.
# E: must be logged in, cookie upgraded in correct slot.
test 'web/05_cookie/3_auto', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["autologin=2:1001,joe,,apmRvfeB1FPOGUBK9a3Ayw"]);

    assert_contains $result->{text}, 'data-logged-in="0"';

    # assert_contains $result->{text}, 'data-logged-in="1"';
    # assert_contains $result->{text}, 'data-user="joe"';
    # assert !exists $result->{cookies_by_name}{session};
    # assert_equals $result->{cookies_by_name}{autologin}, "3:123456789123456789:joe";
    # assert $result->{text} !~ /User manager is down/;
};

# Test API login.
# A: present an API token.
# E: must NOT be logged in, API token not accepted by index.cgi.
test 'web/05_cookie/api', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Query => [ api_token => "3:123456789123456789:joe" ]);
    assert_contains $result->{text}, 'data-logged-in="0"';
    assert !exists $result->{cookies_by_name}{session};
    assert !exists $result->{cookies_by_name}{autologin};
    assert $result->{text} !~ /User manager is down/;
};

# Test renewal.
# A: present a v3 session cookie that is about to expire.
# E: must be logged in, cookie updated.
test 'web/05_cookie/3_ok', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=3:123456789123456789:joe"], Until => int(time()/60) + 100);
    assert_contains $result->{text}, 'data-logged-in="1"';
    assert_contains $result->{text}, 'data-user="joe"';
    assert  exists $result->{cookies_by_name}{session};
    assert !exists $result->{cookies_by_name}{autologin};
    assert $result->{text} !~ /User manager is down/;

    my $old_token = "123456789123456789";
    my $new_token;
    $result->{cookies_by_name}{session} =~ /^3:(.*?):/ and $new_token = $1;
    assert $new_token;
    assert_differs $old_token, $new_token;

    # Both tokens still exist
    my $dbc = setup_connect_app($setup, 'db');
    assert conn_call($dbc, 'sismember', 'token:all', $new_token);
    assert conn_call($dbc, 'sismember', 'token:all', $old_token);
    assert_equals conn_call($dbc, 'hget', 'token:t:'.$old_token, 'user'), '1001';
    assert_equals conn_call($dbc, 'hget', 'token:t:'.$new_token, 'user'), '1001';
};

# Test expiration.
# A: present a v3 session cookie that is expired.
# E: must NOT be logged in.
test 'web/05_cookie/3_ok', sub {
    my $setup = shift;
    my $result = call_cgi($setup, Cookies => ["session=3:123456789123456789:joe"], Until => int(time()/60) - 100);
    assert_contains $result->{text}, 'data-logged-in="0"';
    assert !exists $result->{cookies_by_name}{session};
    assert !exists $result->{cookies_by_name}{autologin};
    assert $result->{text} !~ /User manager is down/;

    # Old token deleted
    my $dbc = setup_connect_app($setup, 'db');
    assert !conn_call($dbc, 'sismember', 'token:all', '123456789123456789');
};




# call_cgi($setup, opts=>value....)
sub call_cgi {
    my $setup = shift;
    my %opts = @_;

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
    conn_call($dbc, qw(hmset user:1001:profile realname Joseph screenname Joe));

    # Create tokens
    my $end = $opts{Until} || 1000000000; # Year 3871 problem
    conn_call($dbc, qw(hmset token:t:123456789123456789 user 1001 type login until), $end);
    conn_call($dbc, qw(sadd token:all 123456789123456789));
    conn_call($dbc, qw(sadd user:1001:tokens:login 123456789123456789));

    my $cgi = cgi_new($setup, "index.cgi");
    cgi_add_cookie($cgi, @{$opts{Cookies}})
        if $opts{Cookies};
    cgi_set_get_params($cgi, @{$opts{Query}})
        if $opts{Query};
    my $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);

    $result;
}
