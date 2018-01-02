#!/usr/bin/perl -w
#
#  Performance test: groupls
#
use strict;
use c2systest;

test 'talk/p01_groupls', sub {
    # Setup
    my $setup = shift;
    my $talk = setup_add_talk($setup);
    my $db = setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create groups
    my $talkc = service_connect($talk);
    conn_call($talkc, qw(groupadd root description foo));
    foreach (1 .. 5) {
        conn_call($talkc, qw(forumadd name x parent root));
    }
    conn_call($talkc, qw(groupadd active parent root));
    conn_call($talkc, qw(groupadd finished parent root));

    # Verify
    my %p = @{ conn_call($talkc, qw(groupls root)) };
    assert_num_equals scalar(@{$p{groups}}), 2;
    assert_num_equals scalar(@{$p{forums}}), 5;

    # Timing loop
    test_timing 'talk groupls root', sub {
        conn_call($talkc, qw(groupls root));
    };
};
