#!/usr/bin/perl -w
#
#  Test file permission setting
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test file permission settings, round-trip.
# A: prepare file system. Use file.cgi to retrieve and change permissions.
# E: correct permissions listed, updates correctly executed.
test 'web/24_fileperm/ui', sub {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Configure database
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hmset default:profile allowupload 1 limitfiles 10 limitkbytes 10));

    # Create a few users
    my $uid    = c2service::setup_add_user($setup, 'joe');
    my $other1 = c2service::setup_add_user($setup, 'fred');
    my $other2 = c2service::setup_add_user($setup, 'barney');
    my $other3 = c2service::setup_add_user($setup, 'wilma');
    conn_call($db, 'hset', "user:$other1:profile", 'screenname', 'FredF');
    conn_call($db, 'hset', "user:$other2:profile", 'screenname', 'BarneyR');
    conn_call($db, 'hset', "user:$other3:profile", 'screenname', 'WilmaR');

    # Cookie for joe
    my $cookie = setup_make_cookie($setup, $uid);

    # Set up permissions
    my $fs = setup_connect_app($setup, 'file');
    conn_call($fs, 'mkdir', 'u/joe/dir');
    conn_call($fs, 'setperm', 'u/joe/dir', '*', 'r');
    conn_call($fs, 'setperm', 'u/joe/dir', $other1, 'l');
    conn_call($fs, 'setperm', 'u/joe/dir', $other2, 'rl');

    # Fetch editor
    my $edit = cgi_new($setup, 'file.cgi');
    cgi_set_path($edit, '/joe/dir/');
    cgi_set_post_params($edit, action => 'settings');
    cgi_add_cookie($edit, $cookie);
    my $edit_result = cgi_run($edit);
    my $edit_html = cgi_verify_result($edit, $edit_result);
    my $edit_form = $edit_html->{forms_by_name}{foldersettings};

    # Verify edit form
    assert $edit_form;
    assert_equals $edit_form->{values}{perms_r_all}, '1';
    assert_equals $edit_form->{values}{perms_w_all}, '';
    assert_equals $edit_form->{values}{perms_l_all}, '';

    assert_equals $edit_form->{values}{perms_r_u_barney}, '1';
    assert_equals $edit_form->{values}{perms_w_u_barney}, '';
    assert_equals $edit_form->{values}{perms_l_u_barney}, '1';

    assert_equals $edit_form->{values}{perms_r_u_fred}, '';
    assert_equals $edit_form->{values}{perms_w_u_fred}, '';
    assert_equals $edit_form->{values}{perms_l_u_fred}, '1';

    assert_equals $edit_form->{values}{perms_users}, 'barney,fred';

    # Screen names must appear
    assert_contains $edit_result->{text}, 'BarneyR';
    assert_contains $edit_result->{text}, 'FredF';

    # Modify the form and save
    delete $edit_form->{values}{submit_save};
    $edit_form->{values}{perms_new_user} = 'wilma';
    $edit_form->{values}{perms_w_new} = '1';
    $edit_form->{values}{perms_l_u_barney} = '';
    $edit_form->{values}{perms_w_u_barney} = '1';

    my $update = cgi_new_form($setup, $edit_form);
    cgi_add_cookie($update, $cookie);
    my $update_result = cgi_run($update);
    my $update_html = cgi_verify_result($update, $update_result);
    my $update_form = $update_html->{forms_by_name}{foldersettings};

    # Verify update form
    assert $update_form;
    assert_equals $update_form->{values}{perms_r_all}, '1';
    assert_equals $update_form->{values}{perms_w_all}, '';
    assert_equals $update_form->{values}{perms_l_all}, '';

    assert_equals $update_form->{values}{perms_r_u_barney}, '1';
    assert_equals $update_form->{values}{perms_w_u_barney}, '1';
    assert_equals $update_form->{values}{perms_l_u_barney}, '';

    assert_equals $update_form->{values}{perms_r_u_fred}, '';
    assert_equals $update_form->{values}{perms_w_u_fred}, '';
    assert_equals $update_form->{values}{perms_l_u_fred}, '1';

    assert_equals $update_form->{values}{perms_r_u_wilma}, '';
    assert_equals $update_form->{values}{perms_w_u_wilma}, '1';
    assert_equals $update_form->{values}{perms_l_u_wilma}, '';

    assert_equals $update_form->{values}{perms_users}, 'barney,fred,wilma';

    # Verify file system state
    my %perms = conn_call_list($fs, 'lsperm', 'u/joe/dir');
    assert_equals $perms{owner}, $uid;

    my %parsed_perms;
    foreach (@{$perms{perms}}) {
        my %ele = @$_;
        $parsed_perms{$ele{user}} = $ele{perms};
    }
    assert_equals $parsed_perms{$other1}, 'l';
    assert_equals $parsed_perms{$other2}, 'rw';
    assert_equals $parsed_perms{$other3}, 'w';
};

# Test file permission settings, round-trip. API.
# A: prepare file system. Use api/file.cgi to retrieve and change permissions.
# E: correct permissions returned, updates correctly executed.
test 'web/24_fileperm/ui', sub {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Configure database
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hmset default:profile allowupload 1 limitfiles 10 limitkbytes 10));

    # Create a few users
    my $uid    = c2service::setup_add_user($setup, 'joe');
    my $other1 = c2service::setup_add_user($setup, 'fred');
    my $other2 = c2service::setup_add_user($setup, 'barney');
    my $other3 = c2service::setup_add_user($setup, 'wilma');
    conn_call($db, 'hset', "user:$other1:profile", 'screenname', 'FredF');
    conn_call($db, 'hset', "user:$other2:profile", 'screenname', 'BarneyR');
    conn_call($db, 'hset', "user:$other3:profile", 'screenname', 'WilmaR');

    # Cookie for joe
    my $cookie = setup_make_cookie($setup, $uid);

    # Set up permissions
    my $fs = setup_connect_app($setup, 'file');
    conn_call($fs, 'mkdir', 'u/joe/dir');
    conn_call($fs, 'setperm', 'u/joe/dir', '*', 'r');
    conn_call($fs, 'setperm', 'u/joe/dir', $other1, 'l');
    conn_call($fs, 'setperm', 'u/joe/dir', $other2, 'rl');

    # List permissions
    my $result = setup_post_api($setup, 'api/file.cgi', $cookie, action => 'lsperm', dir => 'u/joe/dir');
    assert_equals $result->{owner}, 'joe';

    my %parsed_perms = map_permissions($result->{perms});
    assert_equals $parsed_perms{'*'}, 'r';
    assert_equals $parsed_perms{fred}, 'l';
    assert_equals $parsed_perms{barney}, 'rl';

    # Change permissions
    setup_post_api($setup, 'api/file.cgi', $cookie, action => 'setperm', dir => 'u/joe/dir', user => 'wilma', perms => 'w');
    setup_post_api($setup, 'api/file.cgi', $cookie, action => 'setperm', dir => 'u/joe/dir', user => 'barney', perms => 'rw');

    # List permissions again
    $result = setup_post_api($setup, 'api/file.cgi', $cookie, action => 'lsperm', dir => 'u/joe/dir');
    assert_equals $result->{owner}, 'joe';

    %parsed_perms = map_permissions($result->{perms});
    assert_equals $parsed_perms{'*'}, 'r';
    assert_equals $parsed_perms{fred}, 'l';
    assert_equals $parsed_perms{barney}, 'rw';
    assert_equals $parsed_perms{wilma}, 'w';

    # Verify file system state
    my %perms = conn_call_list($fs, 'lsperm', 'u/joe/dir');
    assert_equals $perms{owner}, $uid;
    
    %parsed_perms = ();
    foreach (@{$perms{perms}}) {
        my %ele = @$_;
        $parsed_perms{$ele{user}} = $ele{perms};
    }
    assert_equals $parsed_perms{$other1}, 'l';
    assert_equals $parsed_perms{$other2}, 'rw';
    assert_equals $parsed_perms{$other3}, 'w';
};


sub map_permissions {
    my $p = shift;
    my %perms;
    foreach (@$p) {
        $perms{$_->{user}} = $_->{perms};
    }
    %perms;
}
