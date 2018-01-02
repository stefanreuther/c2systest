#!/usr/bin/perl -w
#
#  Performance test: folderls, folderstat
#
use strict;
use c2systest;

test 'talk/p07_folder', sub {
    # Setup
    my $setup = shift;
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
    my $tc = setup_connect_app($setup, 'talk');
    my $db = setup_connect_app($setup, 'db');

    # Configure default folders
    conn_call($db, qw(sadd default:folder:all 1 2));
    conn_call($db, qw(hmset default:folder:1:header name Inbox description Received...));
    conn_call($db, qw(hmset default:folder:2:header name Outbox description Sent...));

    # Create user folders
    conn_call($tc, qw(user a));
    conn_call($tc, qw(foldernew Saved description Saved...));
    conn_call($tc, qw(foldernew Spam description Unwanted...));
    conn_call($tc, qw(foldernew Treaties description Diplomacy...));

    # Test
    my @list = conn_call_list($tc, qw(folderls));
    assert_equals scalar(@list), 5;

    test_timing 'talk folderls', sub {
        conn_call($tc, qw(folderls));
    };

    test_timing 'talk folderstat 1', sub {
        conn_call($tc, qw(folderstat 1));
    };

    test_timing 'talk folderstat 101', sub {
        conn_call($tc, qw(folderstat 101));
    };
};
