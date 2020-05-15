#!/usr/bin/perl -w
#
#  Test skin configuration
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

my $DESKTOP_UA = 'Opera/8.00 (Windows NT 5.1; U; en)';
my $MOBILE_UA = 'Mozilla/5.0 (Android 4.4; Mobile; rv:63.0) Gecko/63.0 Firefox/63.0';

test 'web/16_skin', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);   # as of 20190403, settings.cgi frontpage needs mailout to display email status
    setup_start_wait($setup);

    my $uid = c2service::setup_db_add_user($setup, 'u');
    my $cookie = setup_make_cookie($setup, $uid);
    my $settings;

    # Initial invocation: must be desktop
    check_page($setup, [$cookie], 'class="desktop"');

    # Enable mobile skin
    {
        my $cgi = cgi_new($setup, 'settings.cgi');
        cgi_set_ua($cgi, $DESKTOP_UA);
        cgi_set_post_params($cgi, action => 'save_prefs', prefs_skin => 'mobile');
        cgi_add_cookie($cgi, $cookie);

        my $result = cgi_run($cgi);
        assert_starts_with $result->{headers}{status}, 302;
        assert_equals $result->{headers}{location}, '/settings.cgi';

        # Must not override the session cookie, but define a new settings cookie
        assert !exists $result->{cookies_by_name}{session};
        assert exists $result->{cookies_by_name}{settings};
        $settings = "settings=".$result->{cookies_by_name}{settings};
    }

    # Check that mobile skin is being used
    check_page($setup, [$cookie, $settings], 'class="mobile"');

    # Enable desktop skin
    {
        my $cgi = cgi_new($setup, 'settings.cgi');
        cgi_set_ua($cgi, $DESKTOP_UA);
        cgi_set_post_params($cgi, action => 'save_prefs', prefs_skin => 'desktop');
        cgi_add_cookie($cgi, $cookie);

        my $result = cgi_run($cgi);
        assert_starts_with $result->{headers}{status}, 302;
        assert_equals $result->{headers}{location}, '/settings.cgi';

        # Must not override the session cookie, but define a new settings cookie
        assert !exists $result->{cookies_by_name}{session};
        assert exists $result->{cookies_by_name}{settings};
        $settings = "settings=".$result->{cookies_by_name}{settings};
    }

    # Must now use desktop skin
    check_page($setup, [$cookie], 'class="desktop"');
};

sub check_page {
    my ($setup, $cookies, $text) = @_;

    my $cgi = cgi_new($setup, 'settings.cgi');
    cgi_set_ua($cgi, $DESKTOP_UA);
    cgi_add_cookie($cgi, @$cookies);

    my $result = cgi_run($cgi);
    $result->{text} =~ s/\s+\"/\"/g;                             # Make sure we recognize 'class="desktop"' and 'class="desktop "'
    assert_starts_with $result->{headers}{status}, 200;
    assert_contains $result->{text}, $text;

    # No new cookies
    assert_list_equals [keys %{$result->{cookies_by_name}}], [];
}
