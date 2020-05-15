#!/usr/bin/perl -w
#
#  Test user.cgi
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test user.cgi, normal case.
# A: prepare a user. Invoke user.cgi for that user.
# E: proper HTML generated citing user's screen name
test 'web/28_userhome/normal', sub {
    # Setup
    my $setup = shift;
    prepare($setup);

    # Create user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, 'adduser', 'joe', 'secret', 'screenname', '<<Joe>>');
    my $cookie = setup_make_cookie($setup, $uid);

    # Call CGI
    my $cgi = cgi_new($setup, 'user.cgi');
    cgi_add_cookie($cgi, $cookie);
    my $result = cgi_run($cgi);
    assert_contains $result->{text}, '<li class="navtrail-self">&#60;&#60;Joe&#62;&#62;</li>';
    assert_contains $result->{text}, 'data-logged-in="1"';
    assert_contains $result->{text}, 'data-user="joe"';
};

# Test user.cgi, normal case.
# A: Invoke user.cgi without user context
# E: redirect to login
test 'web/28_userhome/anon', sub {
    # Setup
    my $setup = shift;
    prepare($setup);

    # Call CGI without cookie
    my $cgi = cgi_new($setup, 'user.cgi');
    my $result = cgi_run($cgi);
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/login.cgi';
};



sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_usermgr($setup);
    setup_add_userfile($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Need to initialize database; we need the definition of "inbox" to obtain list of mails in inbox
    c2service::setup_db_init($setup);
}
