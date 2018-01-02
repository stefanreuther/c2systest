#!/usr/bin/perl -w
#
#  Performance test: nntpposthead
#
use strict;
use c2systest;

test 'talk/p06_nntphead', sub {
    # Setup
    my $setup = shift;
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
    my $tc = setup_connect_app($setup, 'talk');
    my $db = setup_connect_app($setup, 'db');

    # Create a user
    conn_call($db, qw(hmset user:a:profile screenname SN email a@b infoemailflag 1));
    conn_call($db, qw(set user:a:name aa));

    # Create a forum and a posting
    assert_equals conn_call($tc, qw(forumadd name Forum newsgroup ng.forum parent root readperm all writeperm all)), 1;
    assert_equals conn_call($tc, qw(postnew 1 Subject text:content user a)), 1;

    # Verify
    conn_call($tc, qw(user a));
    assert conn_call_list($tc, qw(nntpposthead 1));
    
    # Timing
    test_timing 'talk nntpposthead 1', sub {
        conn_call($tc, qw(nntpposthead 1));
    };
};
