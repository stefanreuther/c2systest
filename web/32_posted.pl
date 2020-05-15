#!/usr/bin/perl -w
#
#  Test "postings by user" lists - talk/user, mail/posted
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test retrieval of own postings.
# A: retrieve mail/posted.cgi as fred.
# E: must produce correct post list
test 'web/32_posted/own/self', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'mail/posted.cgi');
    cgi_add_cookie($cgi, setup_make_cookie($setup, 1001));
    my $result = cgi_run($cgi);

    check($cgi, $result, 'mail/posted.cgi');
};

# Test retrieval of own postings when not logged in.
# A: retrieve mail/posted.cgi without auth.
# E: must redirect to login
test 'web/32_posted/own/anon', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'mail/posted.cgi');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/login.cgi?returnto=mail/posted.cgi';
};

# Test retrieval of own postings through public interface.
# A: retrieve talk/user.cgi/fred as fred.
# E: must produce correct post list
test 'web/32_posted/user/own', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'talk/user.cgi');
    cgi_add_cookie($cgi, setup_make_cookie($setup, 1001));
    cgi_set_path($cgi, '/fred');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    check($cgi, $result, 'talk/user.cgi/fred');
};

# Test retrieval of own postings through public interface from other user.
# A: retrieve talk/user.cgi/fred as wilma.
# E: must produce correct post list
test 'web/32_posted/user/other', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'talk/user.cgi');
    cgi_add_cookie($cgi, setup_make_cookie($setup, 1002));
    cgi_set_path($cgi, '/fred');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    check($cgi, $result, 'talk/user.cgi/fred');
};

# Test retrieval of own postings through public interface when not logged in.
# A: retrieve talk/user.cgi/fred as anonymous user.
# E: must produce correct post list
test 'web/32_posted/user/anon', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'talk/user.cgi');
    cgi_set_path($cgi, '/fred');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    check($cgi, $result, 'talk/user.cgi/fred');
};

# Test retrieval of user postings with invalid user Id.
# A: retrieve talk/user.cgi/other as anonymous fred.
# E: must produce error.
test 'web/32_posted/user/unknown', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'talk/user.cgi');
    cgi_add_cookie($cgi, setup_make_cookie($setup, 1001));
    cgi_set_path($cgi, '/other');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    assert_starts_with $result->{headers}{status}, 404;
};

# Test retrieval of user postings with no user Id.
# A: retrieve talk/user.cgi/other as anonymous fred.
# E: must redirect to talk.
test 'web/32_posted/user/none', sub {
    my $setup = shift;
    prepare($setup);

    my $cgi = cgi_new($setup, 'talk/user.cgi');
    cgi_add_cookie($cgi, setup_make_cookie($setup, 1001));
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/talk/';
};







sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create two users
    c2service::setup_db_init($setup);

    my $uc = setup_connect_app($setup, 'user');
    assert_equals conn_call($uc, 'adduser', 'fred', 'secret', 'screenname', 'Fred F'), '1001';
    assert_equals conn_call($uc, 'adduser', 'wilma', 'secret', 'screenname', 'Wilma F'), '1002';

    # Create a forum and have fred post something
    my $tc = setup_connect_app($setup, 'talk');
    my $fid = conn_call($tc, 'forumadd', 'readperm', 'all', 'name', 'Talk');
    assert_equals $fid, 1;

    foreach (1 .. 5) {
        conn_call($tc, 'postnew', $fid, "Sub $_", "text:Text $_", 'user', '1001');
    }
}

sub check {
    my ($cgi, $result, $path) = @_;
    my $html = cgi_verify_result($cgi, $result);

    # Proper title
    assert_contains $result->{text}, '<title>PlanetsCentral - Fred F - Forum Postings';

    # Proper links
    my $links = normalize_links($path, $html->{links});
    foreach (1 .. 5) {
        assert $links->{"talk/post.cgi/$_-Sub-$_"} > 0;
    }
    assert $links->{"talk/forum.cgi/1-Talk"} > 0;
}
