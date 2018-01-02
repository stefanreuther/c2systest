#!/usr/bin/perl -w
#
#  Performance test: nntplist, nntpgrouplist
#
use strict;
use c2systest;

test 'talk/p05_nntp', sub {
    # Setup
    my $setup = shift;
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
    my $tc = setup_connect_app($setup, 'talk');

    # Create groups
    conn_call($tc, qw(groupadd root name Root description Forums));
    conn_call($tc, qw(groupadd active name Active description Games parent root));

    # Create a few normal forums
    foreach (1 .. 10) {
        conn_call($tc, 'forumadd', 'name', 'Regular', 'newsgroup', 'ng.regular.'.$_, 'parent', 'root', 'readperm', 'all');
    }

    # Create a few game forums
    foreach (1 .. 10) {
        conn_call($tc, 'forumadd', 'name', 'Game', 'newsgroup', 'ng.game.'.$_, 'parent', 'active', 'readperm', 'all');
    }

    # Verify
    conn_call($tc, qw(user a));
    assert conn_call_list($tc, 'nntplist');
    assert conn_call_list($tc, 'nntpgroupls', 'root');

    # Test it
    test_timing 'talk nntplist', sub {
        conn_call($tc, 'nntplist');
    };
    test_timing 'talk nntpgroupls root', sub {
        conn_call($tc, 'nntpgroupls', 'root');
    };
};
