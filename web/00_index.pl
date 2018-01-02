#!/usr/bin/perl -w
#
#  Tests for index.cgi
#

use strict;
use c2systest;
use c2cgitest;

# Basic test with no services
test 'web/00_index/no_services', sub {
    # Just start the (empty) setup
    my $setup = shift;
    setup_start($setup);

    # Just run the CGI with no parameters
    my $cgi = cgi_new($setup, 'index.cgi');
    my $result = cgi_run($cgi);

    # Sanity-check received headers
    assert_equals $result->{headers}{'status'},       '200';
    assert_equals $result->{headers}{'content-type'}, 'text/html; charset=UTF-8';

    # "misconfigured" appears if the templates cannot be found
    assert $result->{text} !~ /misconfigured/;

    # "ui-errordialog" appears on the output if anything within index.cgi throws
    assert $result->{text} !~ /ui-errordialog/;

    # News/Host are listed as not available.
    assert $result->{text} =~ /newsfeed is not available/;
    assert $result->{text} =~ /host is not available/;

    cgi_verify_result($cgi, $result);
};

# Basic test with all services
test 'web/00_index/empty_services', sub {
    # Add and start a bunch of services.
    # Index page needs essentially all of them:
    #   talk (needs db, mailout)
    #   host (needs db, mailout, file, hostfile)
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_start_wait($setup);

    # Run CGI with no parameters
    my $cgi = cgi_new($setup, 'index.cgi');
    my $result = cgi_run($cgi);

    # Sanity-check received headers
    assert_equals $result->{headers}{'status'},       '200';
    assert_equals $result->{headers}{'content-type'}, 'text/html; charset=UTF-8';

    # Sanity-check HTML
    assert $result->{text} !~ /misconfigured/;
    assert $result->{text} !~ /ui-errordialog/;

    # At this point, the newsfeed is not reported as not available,
    # but host is still not available because it has no games.
    assert $result->{text} !~ /newsfeed is not available/;
    assert $result->{text} =~ /host is not available/;

    cgi_verify_result($cgi, $result);
};

# Test redirect on path
test 'web/00_index/redir_path', sub {
    # Just start the (empty) setup
    my $setup = shift;
    setup_start($setup);

    # Just run the CGI with no parameters
    my $cgi = cgi_new($setup, 'index.cgi');
    cgi_set_path($cgi, "/wherever");
    my $result = cgi_run($cgi);

    # Result must redirect to "/"
    assert_equals $result->{headers}{'location'}, '/';

    cgi_verify_result($cgi, $result);
};

# Test POST
test 'web/00_index/post', sub {
    # Just start the (empty) setup
    my $setup = shift;
    setup_start($setup);

    # Just run the CGI with no parameters
    my $cgi = cgi_new($setup, 'index.cgi');
    cgi_set_post_params($cgi, "what", "ever");
    my $result = cgi_run($cgi);

    # POST will be returned normally
    assert_equals $result->{headers}{'status'},       '200';
    assert_equals $result->{headers}{'content-type'}, 'text/html; charset=UTF-8';

    cgi_verify_result($cgi, $result);
};
