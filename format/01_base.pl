#!/usr/bin/perl -w
#
#  Format: basic commands
#
use strict;
use c2systest;

# TestServerFormatFormat::testPack
test 'format/01_base', sub {
    # Setup
    my $setup = shift;
    my $service = setup_add_app($setup, 'format', 'c2format');
    setup_start_wait($setup);
    my $conn = service_connect($service);

    # Basics commands
    assert_equals conn_call($conn, qw(ping)), 'PONG';
    assert_equals conn_call($conn, qw(PING)), 'PONG';

    assert_num_greater length(conn_call($conn, qw(help))), 30;

    # No user context!
    assert_throws sub{ conn_call($conn, qw(user a)) }, 400;
};
