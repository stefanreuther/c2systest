#!/usr/bin/perl -w
#
#  Test help: must correctly verify path information, does not need services.
#
use strict;
use c2systest;
use c2cgitest;

test 'web/02_help', sub {
    my $setup = shift;

    # "help.cgi/" produces content
    my $cgi = cgi_new($setup, 'help.cgi');
    cgi_set_path($cgi, '/');
    my $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 200;

    # "help.cgi/about" produces content
    $cgi = cgi_new($setup, 'help.cgi');
    cgi_set_path($cgi, '/about');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 200;

    # Nonexistant page should generate 404
    $cgi = cgi_new($setup, 'help.cgi');
    cgi_set_path($cgi, '/does-not-exist-I-hope');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 404;

    # "help.cgi" redirects to "help.cgi/".
    $cgi = cgi_new($setup, 'help.cgi');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 302;
    assert_equals $r->{headers}{location}, '/help.cgi/';
};
