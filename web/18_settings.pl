#!/usr/bin/perl -w
#
#  Test settings.cgi front-page
#
use strict;
use c2systest;
use c2cgitest;

test 'web/18_settings', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create stuff
    my $uc = setup_connect_app($setup, 'user');
    my $id = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $id);

    # Set values
    conn_call($uc, 'set', $id,
              email => 'mail@spam',
              realname => 'Joe R. User',
              screenname => 'Joey',
              infocountry => 'Murica',
              infowebsite => 'http://foo.bar',
              talkwatchindividual => 1);

    # Request form
    my $result = retrieve_settings($setup, $cookie);

    # Verify keywords
    assert_contains $result->{text}, 'Joe R. User';
    assert_contains $result->{text}, 'Joey';
    assert_contains $result->{text}, 'Murica';
    assert_contains $result->{text}, '<a href="http://foo.bar" rel="nofollow"><tt>http://foo.bar</tt></a>';
    assert_contains $result->{text}, 'individual notifications';
    assert_contains $result->{text}, 'mailto:mail@spam';
    assert_contains $result->{text}, '(unconfirmed)';

    # Mark email address confirmed and retry
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'email:mail@spam:status', "status/$id", 'c');
    $result = retrieve_settings($setup, $cookie);
    assert_contains $result->{text}, '(confirmed)';
};


sub retrieve_settings {
    my ($setup, $cookie) = @_;
    my $cgi = cgi_new($setup, 'settings.cgi');
    cgi_add_cookie($cgi, $cookie);
    my $result = cgi_run($cgi);
    html_verify('settings.cgi', $result->{text});
    $result;
}
