#!/usr/bin/perl -w
#
#  Test reset.cgi, new (token-based) version
#

use strict;
use c2systest;
use c2cgitest;
use Digest::MD5 ('md5_base64');

# Test password reset, new (token-based) version.
# A: present a hand-crafted reset link using prepared token
# E: link must correctly be parsed and user redirected
test 'web/13_resetnew/ok', sub {
    my $setup = shift;

    # Call CGI
    my $result = call_cgi($setup, Query => [token => '123456789123456789']);

    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/settings.cgi?action=edit_password';
    assert_starts_with $result->{cookies_by_name}{session}, "3:";
};

# Test password reset, expired token.
# A: present a hand-crafted reset link using prepared token
# E: link must correctly be parsed and user redirected
test 'web/13_resetnew/expired', sub {
    my $setup = shift;

    # Call CGI
    my $result = call_cgi($setup, Query => [token => '123456789123456789'], Until => int(time()/60) - 5);

    assert_starts_with $result->{headers}{status}, 200;
    assert_contains $result->{text}, 'ui-errordialog';
};

# Test password reset, nonexistant token.
# A: present a hand-crafted reset link using prepared token
# E: link must correctly be parsed and user redirected
test 'web/13_resetnew/bad', sub {
    my $setup = shift;

    # Call CGI
    my $result = call_cgi($setup, Query => [token => 'aaaaaaaaaa']);

    assert_starts_with $result->{headers}{status}, 200;
    assert_contains $result->{text}, 'ui-errordialog';
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

    # Create a token
    my $end = $opts{Until} || 1000000000; # Year 3871 problem
    conn_call($dbc, qw(hmset token:t:123456789123456789 user 1001 type reset until), $end);
    conn_call($dbc, qw(sadd token:all 123456789123456789));
    conn_call($dbc, qw(sadd user:1001:tokens:reset 123456789123456789));

    my $cgi = cgi_new($setup, "reset.cgi");
    cgi_set_get_params($cgi, @{$opts{Query}})
        if $opts{Query};
    my $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);

    $result;
}
