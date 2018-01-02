#!/usr/bin/perl -w
#
#  Performance test: usernewsrc
#

use strict;
use c2systest;

test 'talk/p04_newsrc', sub {
    # Setup
    my $setup = shift;
    my $talk = setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create preconditions
    my $talkc = service_connect($talk);
    my $fid = conn_call($talkc, qw(forumadd name x));
    assert_equals $fid, 1;

    foreach (1 .. 100) {
        conn_call($talkc, qw(postnew 1 subj text user 100));
    }

    # Verify
    conn_call($talkc, qw(user 200));
    assert_equals conn_call($talkc, qw(usernewsrc firstset range 1 100)), 0;

    # Test
    test_timing 'talk usernewsrc', sub {
        conn_call($talkc, qw(usernewsrc get range 1 100));
    };
};
