#!/usr/bin/perl -w
#
#  Test message discarding: if a connection is lost, or the service restarts, this will leave a partial message.
#  Those are deleted on startup.
#

use strict;
use c2systest;

test 'mailout/03_discard', sub {
    # Start everything
    my $setup = shift;
    setup_add_db($setup);
    my $ms = setup_add_mailout($setup, 1);
    setup_start_wait($setup);
    my $db = setup_connect_app($setup, 'db');

    # Send some messages, and abort the transmission
    foreach (1 .. 5) {
        my $mc = service_connect($ms);
        conn_call($mc, 'mail', 'foo');
        conn_call($mc, 'param', 'i', $_);
    }
    assert_equals conn_call($db, qw(get mqueue:msg:id)), 5;
    assert_set_equals conn_call($db, qw(smembers mqueue:preparing)), [1,2,3,4,5];
    assert_set_equals conn_call($db, qw(smembers mqueue:sending)), [];

    # Stop and restart the mail service
    service_stop($ms);
    service_start($ms);

    # Verify
    my $mc = service_connect_wait($ms);
    assert_equals conn_call($db, qw(get mqueue:msg:id)), 5;
    assert_set_equals conn_call($db, qw(smembers mqueue:preparing)), [];
    assert_set_equals conn_call($db, qw(smembers mqueue:sending)), [];
    assert_set_equals conn_call($db, qw(keys mqueue:*)), ['mqueue:msg:id'];
};
