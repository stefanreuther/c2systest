#!/usr/bin/perl -w
#
#  File: CommandHandler
#
#  Synced with TestServerFileCommandHandler, 20170923
#
use strict;
use c2systest;

# TestServerFileCommandHandler::testIt
test 'file/50_ch', sub {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_start_wait($setup);

    my $fc = setup_connect_app($setup, 'file');

    # Invalid
    assert_throws sub{ conn_call($fc, ()) };

    # Ping
    assert_equals conn_call($fc, 'ping'), 'PONG';
    assert_equals conn_call($fc, 'PING'), 'PONG';

    # User
    conn_call($fc, 'user', '1024');

    # Help
    assert_num_greater length(conn_call($fc, 'HELP')), 30;

    # Actual commands, all fail
    # These fail with 403, because user 1024 cannot read the root directory.
    assert_throws sub{ conn_call($fc, 'GET', 'foo') }, 403;
    assert_throws sub{ conn_call($fc, 'LS', 'bar') }, 403;
    assert_throws sub{ conn_call($fc, 'LSREG', 'bar') }, 403;
    assert_throws sub{ conn_call($fc, 'LSGAME', 'bar') }, 403;
};
