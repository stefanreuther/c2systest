#!/usr/bin/perl -w
#
#  Test file upload limits (quota)
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test normal behaviour.
# A: create a standard situation, load file.cgi
# E: upload form must be shown
test 'web/23_filelimit/normal', sub {
    my $setup = shift;
    my $p = prepare($setup);

    conn_call(setup_connect_app($setup, 'file'), 'put', "u/joe/file", 'x');

    my $html = check_list($setup, $p);
    assert $html->{forms_by_name}{fileuploadform};

    my $result = check_upload($setup, $p);
    assert_starts_with $result->{headers}{status}, 302;

    assert_equals conn_call(setup_connect_app($setup, 'file'), 'get', "u/joe/hi.txt"), "hi there";
};

# Test forbidden upload.
# A: set 'allowupload=0', load file.cgi
# E: upload form must not be shown
test 'web/23_filelimit/forbidden', sub {
    my $setup = shift;
    my $p = prepare($setup);

    conn_call(setup_connect_app($setup, 'user'), 'set', $p->{uid}, 'allowupload', 0);

    my $html = check_list($setup, $p);
    assert !$html->{forms_by_name}{fileuploadform};

    check_upload_fail($setup, $p);
};

# Test file count limit.
# A: create too many files, load file.cgi
# E: upload form must not be shown
test 'web/23_filelimit/too_many', sub {
    my $setup = shift;
    my $p = prepare($setup);

    my $fs = setup_connect_app($setup, 'file');
    foreach (1 .. 10) {
        conn_call($fs, 'put', "u/joe/$_", "hi");
    }

    my $html = check_list($setup, $p);
    assert !$html->{forms_by_name}{fileuploadform};

    check_upload_fail($setup, $p);
};

# Test file size limit.
# A: create too many files, load file.cgi
# E: upload form must not be shown
test 'web/23_filelimit/too_large', sub {
    my $setup = shift;
    my $p = prepare($setup);

    conn_call(setup_connect_app($setup, 'file'), 'put', "u/joe/file", 'x' x 20000);

    my $html = check_list($setup, $p);
    assert !$html->{forms_by_name}{fileuploadform};

    check_upload_fail($setup, $p);
};



sub prepare {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_router($setup);
    setup_start_wait($setup);

    # Configure database
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hmset default:profile allowupload 1 limitfiles 10 limitkbytes 10));

    # Create a user
    my $uid = c2service::setup_add_user($setup, 'joe');

    # Cookie
    my $uc = setup_connect_app($setup, 'user');
    my $cookie = setup_make_cookie($setup, $uid);

    return {cookie => $cookie,
            uid => $uid};
}

# Check list (=just load index.cgi)
sub check_list {
    my ($setup, $p) = @_;
    my $cgi = cgi_new($setup, 'file.cgi');
    cgi_set_path($cgi, '/joe/');
    cgi_add_cookie($cgi, $p->{cookie});
    my $result = cgi_run($cgi);
    return cgi_verify_result($cgi, $result);
}

# Check upload.
sub check_upload {
    my ($setup, $p) = @_;
    my $cgi = cgi_new($setup, 'file.cgi');
    cgi_set_path($cgi, '/joe/');
    cgi_add_cookie($cgi, $p->{cookie});
    cgi_set_upload_params($cgi,
                          {name=>'action', value=>'upload'},
                          {name=>'file', value=>'hi there', filename=>'hi.txt'});
    return cgi_run($cgi);
}

# Check upload and expect it to fail.
sub check_upload_fail {
    my ($setup, $p) = @_;

    my $result = check_upload($setup, $p);
    assert_starts_with $result->{headers}{status}, 200;
    assert_contains $result->{text}, 'ui-errordialog';

    my $fs = setup_connect_app($setup, 'file');
    assert_throws sub{ conn_call($fs, 'get', 'u/joe/hi.txt') }, 404;
}
