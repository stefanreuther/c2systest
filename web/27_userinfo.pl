#!/usr/bin/perl -w
#
#  Test userinfo.cgi
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

my @FULL_PROFILE = (inforealnameflag => 1,
                    infoemailflag => 1,
                    screenname => 'Joseph',
                    email => 'joe@provi.der',
                    infocountry => '<<Neuland>>',
                    infotown => '<<Horstenlochnitz>>',
                    infooccupation => '<<Schluckimpfer>>',
                    infobirthday => '<<May 35>>',
                    infowebsite => '<<http://x.y/>>');


# Test user info for a fully-populated user.
# A: prepare a full user profile
# E: retrieve user profile with logged-in user, verify that all fields are present.
test 'web/27_userinfo/full', sub {
    my $setup = shift;
    prepare($setup);

    # Create and populate user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, qw(adduser joe secret), @FULL_PROFILE);

    # Mark email confirmed
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:joe@provi.der:status', 'status/'.$uid, 'c');

    # Create a bunch of forum posts
    my $talk = setup_connect_app($setup, 'talk');
    my $fid = conn_call($talk, 'forumadd', 'allowpost', 'all');
    foreach (1..42) {
        conn_call($talk, 'postnew', $fid, 'subj', 'text:'.$_, 'user', $uid);
    }

    # Invoke user-info page from another user
    my $result = call_from_user($setup, $uc);

    # Verify content
    assert_contains $result->{text}, '<li class="navtrail-self">Joseph</li>';
    assert_contains $result->{text}, '<dt>Email address</dt><dd><a href="mailto:joe@provi.der"><tt>joe@provi.der</tt></a></dd>';
    assert_contains $result->{text}, '<dt>Country</dt><dd>&#60;&#60;Neuland&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Town</dt><dd>&#60;&#60;Horstenlochnitz&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Occupation</dt><dd>&#60;&#60;Schluckimpfer&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Birthday</dt><dd>&#60;&#60;May 35&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Website</dt><dd>&#60;&#60;http://x.y/&#62;&#62;</dd>';
    assert_contains $result->{text}, '<a href="/talk/user.cgi/joe">42</a></dd>';
};

# Test user info for a fully-populated user, not logged-in observer.
# A: prepare a full user profile
# E: retrieve user profile with not-logged-in user, verify that email is not shown.
test 'web/27_userinfo/anon', sub {
    my $setup = shift;
    prepare($setup);

    # Create and populate user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, qw(adduser joe secret), @FULL_PROFILE);

    # Mark email confirmed
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:joe@provi.der:status', 'status/'.$uid, 'c');

    # Invoke user-info page without user context
    my $cgi = cgi_new($setup, 'userinfo.cgi');
    cgi_set_path($cgi, "/joe");
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify content
    assert_contains $result->{text}, '<li class="navtrail-self">Joseph</li>';
    assert $result->{text} !~ /<dt>Email address/;
    assert_contains $result->{text}, '<dt>Country</dt><dd>&#60;&#60;Neuland&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Town</dt><dd>&#60;&#60;Horstenlochnitz&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Occupation</dt><dd>&#60;&#60;Schluckimpfer&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Birthday</dt><dd>&#60;&#60;May 35&#62;&#62;</dd>';
    assert_contains $result->{text}, '<dt>Website</dt><dd>&#60;&#60;http://x.y/&#62;&#62;</dd>';
};

# Test user info for a partially-populated user.
# A: prepare a partial user profile
# E: retrieve user profile with logged-in user, verify that only filled fields are present.
test 'web/27_userinfo/partial', sub {
    my $setup = shift;
    prepare($setup);

    # Create and populate user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, qw(adduser joe secret),
                        infoemailflag => 1,
                        email => 'joe@provi.der',
                        infocountry => '<<Neuland>>');

    # Mark email confirmed
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:joe@provi.der:status', 'status/'.$uid, 'r');

    # Invoke user-info page from another user
    my $result = call_from_user($setup, $uc);

    # Verify content
    assert_contains $result->{text}, '<li class="navtrail-self">joe</li>';
    assert_contains $result->{text}, '<dt>Email address</dt><dd>not yet confirmed</dd>';
    assert_contains $result->{text}, '<dt>Country</dt><dd>&#60;&#60;Neuland&#62;&#62;</dd>';
    assert $result->{text} !~ /<dt>Town/;
    assert $result->{text} !~ /<dt>Occupation/;
    assert $result->{text} !~ /<dt>Birthday/;
    assert $result->{text} !~ /<dt>Website/;
    assert $result->{text} !~ m|/talk/user.cgi/joe|;
};

# Test user info for an empty user profile.
# A: prepare an empty user profile
# E: retrieve user profile with logged-in user, verify that only filled fields are present.
test 'web/27_userinfo/empty', sub {
    my $setup = shift;
    prepare($setup);

    # Create and populate user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, qw(adduser joe secret),
                        inforealnameflag => 1,
                        infoemailflag => 0);

    # Mark email confirmed
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:joe@provi.der:status', 'status/'.$uid, 'c');

    # Invoke user-info page from another user
    my $result = call_from_user($setup, $uc);

    # Verify content
    assert_contains $result->{text}, '<li class="navtrail-self">joe</li>';
    assert_contains $result->{text}, 'This user has not provided any public profile information';
    assert $result->{text} !~ /<dt>Email address/;
    assert $result->{text} !~ /<dt>Country/;
    assert $result->{text} !~ /<dt>Town/;
    assert $result->{text} !~ /<dt>Occupation/;
    assert $result->{text} !~ /<dt>Birthday/;
    assert $result->{text} !~ /<dt>Website/;
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_usermgr($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_add_talk($setup);
    setup_add_host($setup);
    setup_start_wait($setup);
}

sub call_from_user {
    my ($setup, $uc) = @_;
    my $uid2 = conn_call($uc, qw(adduser jack secret));
    my $cookie = setup_make_cookie($setup, $uid2);

    my $cgi = cgi_new($setup, 'userinfo.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_path($cgi, "/joe");
    my $result = cgi_run($cgi);
    cgi_verify_result($cgi, $result);
    $result;
}
