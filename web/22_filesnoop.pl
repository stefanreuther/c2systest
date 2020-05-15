#!/usr/bin/perl -w
#
#  Test file upload content snooping
#

use strict;
use c2systest;
use c2service;
use c2cgitest;

test 'web/22_filesnoop', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_router($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create a user using regular mechanism
    my $fs = setup_connect_app($setup, 'file');
    conn_call($fs, 'mkdir', 'u');
    my $cookie = create_user($setup, 'uu');

    # Set permissions
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hmset default:profile allowupload 1 limitfiles 1000 limitkbytes 1000));

    # Create some folders as user
    foreach (1..10) {
        conn_call($fs, 'mkdir', 'u/uu/'.$_);
    }

    # Upload files
    # - ordinary file via user interface
    my $upload1 = cgi_new($setup, 'file.cgi');
    cgi_set_upload_params($upload1,
                          {name=>"file", filename=>"foo.txt", value=>"% phost\nGameName = First Name"},
                          {name=>"action", value=>"upload"});
    cgi_set_path($upload1, '/uu/1/');
    cgi_add_cookie($upload1, $cookie);
    my $upload1_result = cgi_run($upload1);
    assert_starts_with $upload1_result->{headers}{status}, 302;

    # - pconfig.src via user interface
    my $upload2 = cgi_new($setup, 'file.cgi');
    cgi_set_upload_params($upload2,
                          {name=>"file", filename=>"pconfig.src", value=>"% phost\nGameName = Second Name"},
                          {name=>"action", value=>"upload"});
    cgi_set_path($upload2, '/uu/2/');
    cgi_add_cookie($upload2, $cookie);
    my $upload2_result = cgi_run($upload2);
    assert_starts_with $upload2_result->{headers}{status}, 302;

    # - multiple files via user interface
    my $upload3 = cgi_new($setup, 'file.cgi');
    cgi_set_upload_params($upload3,
                          {name=>"file1", filename=>"whatever.txt", value=>"% phost\nGameName = Third Name"},
                          {name=>"name1", value=>"pconfig.src"},
                          {name=>"count", value=>1},
                          {name=>"action", value=>"uploadmulti"});
    cgi_set_path($upload3, '/uu/3/');
    cgi_add_cookie($upload3, $cookie);
    my $upload3_result = cgi_run($upload3);
    assert_starts_with $upload3_result->{headers}{status}, 302;

    # - ordinary file via API
    my $api1 = cgi_new($setup, 'api/file.cgi');
    cgi_set_post_params($api1, action=>'put', file=>'u/uu/4/foo.txt', data=>"% phost\nGameName = Fourth Name");
    cgi_add_cookie($api1, $cookie);
    my $api1_result = cgi_run($api1);
    assert_equals json_parse($api1_result->{text})->{result}, 1;

    # - pconfig.src file via API
    my $api2 = cgi_new($setup, 'api/file.cgi');
    cgi_set_post_params($api2, action=>'put', file=>'u/uu/5/pconfig.src', data=>"% phost\nGameName = Fifth Name");
    cgi_add_cookie($api2, $cookie);
    my $api2_result = cgi_run($api2);
    assert_equals json_parse($api2_result->{text})->{result}, 1;

    # - pconfig.src with no section delimiter via API
    my $api3 = cgi_new($setup, 'api/file.cgi');
    cgi_set_post_params($api3, action=>'put', file=>'u/uu/6/pconfig.src', data=>"  GameName = Sixth Name  ");
    cgi_add_cookie($api3, $cookie);
    my $api3_result = cgi_run($api3);
    assert_equals json_parse($api3_result->{text})->{result}, 1;

    # Verify
    assert_equals conn_call($fs, 'propget', 'u/uu/1', 'name'), '';
    assert_equals conn_call($fs, 'propget', 'u/uu/2', 'name'), 'Second Name';
    assert_equals conn_call($fs, 'propget', 'u/uu/3', 'name'), 'Third Name';
    assert_equals conn_call($fs, 'propget', 'u/uu/4', 'name'), '';
    assert_equals conn_call($fs, 'propget', 'u/uu/5', 'name'), 'Fifth Name';
    assert_equals conn_call($fs, 'propget', 'u/uu/6', 'name'), 'Sixth Name';
};




# Create a user.
sub create_user {
    my $setup = shift;
    my $username = shift;

    my $cgi = cgi_new($setup, "signup.cgi");
    cgi_set_post_params($cgi, username => $username, realname => $username, pass1 => "a", pass2 => "a", terms => "read", nerf => "ok");
    my $result = cgi_run($cgi);
    my $cookie = '';
    foreach (@{$result->{cookies}}) {
        if (/^(session=[^;]*)/) {
            $cookie = $1;
        }
    }
    assert_differs($cookie, '');

    $cookie;
}
