#!/usr/bin/perl -w
#
#  Test forum index.
#
use strict;
use c2systest;
use c2cgitest;

# Forum index with groups, including orphan groups. We had a bug here.
test 'web/01_forumindex/groups', sub {
    # Set up and start
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    my $ts = setup_add_talk($setup);
    setup_start($setup);

    # Prepare
    my $tc = service_connect_wait($ts);

    # Root: regular root group
    conn_call($tc, qw(groupadd root    name Root));

    # Child: regular child group
    conn_call($tc, qw(groupadd child   name Child parent root));

    # Orphan: orphan group (typically, the unlisted group).
    # c2talk.pm 1.10 against c2talk-ng and below will enter an endless loop on this one.
    conn_call($tc, qw(groupadd orphan  name Orphan));

    # Orphan2: a variation of Orphan, can possibly reproduce the behaviour of Orphan with c2ng-classic.
    conn_call($tc, qw(groupadd orphan2 name Orphan2 parent root));
    conn_call($tc, qw(groupset orphan2 parent), '');

    # Render index pages
    my $cgi = cgi_new($setup, 'talk/index.cgi');
    my $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 200;

    $cgi = cgi_new($setup, 'talk/index.cgi');
    cgi_set_path($cgi, '/child');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 200;

    $cgi = cgi_new($setup, 'talk/index.cgi');
    cgi_set_path($cgi, '/orphan');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 200;

    $cgi = cgi_new($setup, 'talk/index.cgi');
    cgi_set_path($cgi, '/orphan2');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 200;
};

# Forum index for nonexistant groups.
test 'web/01_forumindex/error', sub {
    # Set up and start
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    my $ts = setup_add_talk($setup);
    setup_start($setup);
    service_connect_wait($ts);

    # Render index pages
    my $cgi = cgi_new($setup, 'talk/index.cgi');
    my $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 404;

    $cgi = cgi_new($setup, 'talk/index.cgi');
    cgi_set_path($cgi, '/hi');
    $r = cgi_run($cgi);
    assert_starts_with $r->{headers}{status}, 404;
};
