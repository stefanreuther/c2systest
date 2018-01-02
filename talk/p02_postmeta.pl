#!/usr/bin/perl -w
#
#  Performance test: post metadata (forumlspost, threadstat)
#

use strict;
use c2systest;

test 'talk/p02_postmeta', sub {
    # Setup
    my $setup = shift;
    my $talk = setup_add_talk($setup);
    my $db = setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create forums
    my $talkc = service_connect($talk);
    my $fid = conn_call($talkc, qw(forumadd name x));
    assert_equals $fid, 1;

    # Create 100 posts in 10 threads
    foreach (1 .. 10) {
        my $pid = conn_call($talkc, 'postnew', '1', 'subj '.$_, 'text:lorem ipsum...', 'user', '100');
        if ($_ == 1) {
            assert_equals $pid, 1;
        }
        foreach (2 .. 10) {
            conn_call($talkc, 'postreply', $pid, 're: subj '.$_, 'text:reply...', 'user', '200');
        }
    }

    # Get thread Id
    my $tid = conn_call($talkc, 'postget', 1, 'thread');
    assert_equals $tid, 1;

    # Verify
    assert_equals scalar(@{ conn_call($talkc, qw(forumlspost 1)) }), 100;

    # Timing loop
    test_timing 'talk forumlspost 1', sub {
        conn_call($talkc, qw(forumlspost 1));
    };
    test_timing 'talk threadstat 1', sub {
        conn_call($talkc, qw(threadstat 1));
    };
};
