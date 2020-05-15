#!/usr/bin/perl -w
#
#  Mailout: MailQueue unit tests
#
#  Synced with TestServerMailoutMailQueue, 20171111
#
use strict;
use c2systest;

# TestServerMailoutMailQueue::testIt: simple test
test 'mailout/50_mailqueue/send', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Send a message
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, qw(mail tpl uid));
    conn_call($mc, qw(param p v));
    conn_call($mc, qw(attach http://));
    conn_call($mc, qw(send r));

    # Verify db content
    my $db = setup_connect_app($setup, 'db');
    assert_equals conn_call($db, qw(hget mqueue:msg:1:data template)), 'tpl';
    assert_equals conn_call($db, qw(hget mqueue:msg:1:data uniqid)), 'uid';
    assert_equals conn_call($db, qw(hget mqueue:msg:1:args p)), 'v';
    assert_equals conn_call($db, qw(lindex mqueue:msg:1:attach 0)), 'http://';
    assert_set_equals conn_call($db, qw(smembers mqueue:msg:1:to)), ['r'];
    assert_set_equals conn_call($db, qw(smembers mqueue:sending)), [1];
    assert_equals conn_call($db, qw(hget mqueue:uniqid uid)), 1;
};

# TestServerMailoutMailQueue::testSequenceError: Test sequence error: message configuration command without starting a message
test 'mailout/50_mailqueue/sequence', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # These commands all fail, we have no message
    my $mc = setup_connect_app($setup, 'mailout');
    assert_throws sub{ conn_call($mc, qw(param a b)) }, 406;
    assert_throws sub{ conn_call($mc, qw(attach q)) }, 406;
    assert_throws sub{ conn_call($mc, qw(send)) }, 406;
};

# TestServerMailoutMailQueue::testSequenceError2: Test sequence error: startMessage with active message.
test 'mailout/50_mailqueue/sequence2', sub {
    my $setup = shift; 
    setup_add_db($setup); 
    setup_add_mailout($setup); 
    setup_start_wait($setup);

    # Start message
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, qw(mail tpl uid));

    # Try to start another; must fail
    assert_throws sub{ conn_call($mc, qw(mail other x)) }, 406;

    # The original message is still being prepared
    my $db = setup_connect_app($setup, 'db');
    assert_set_equals conn_call($db, qw(smembers mqueue:preparing)), [1];
    assert_equals conn_call($db, qw(hget mqueue:msg:1:data template)), 'tpl';
};

# TestServerMailoutMailQueue::testRequest: Test requesting email, success case.
test 'mailout/50_mailqueue/request', sub {
    my $setup = shift; 
    setup_add_db($setup); 
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'www.url', 'url/');
    setup_add_service_config($setup, 'www.key', '');
    setup_start_wait($setup);

    # Define a user
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd user:all 1002));
    conn_call($db, qw(set uid:tt 1002));
    conn_call($db, qw(set user:1002:name tt));
    conn_call($db, qw(hset user:1002:profile email u@h));

    # Request email confirmation
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, qw(request 1002));

    # This must have generated a confirmation request. Verify db.
    # - message
    assert_equals conn_call($db, qw(hget mqueue:msg:1:data template)), 'confirm';
    assert_equals conn_call($db, qw(hget mqueue:msg:1:data uniqid)), 'confirmation-u@h'; # FIXME: should this be confirmation-1002?
    assert_equals conn_call($db, qw(hget mqueue:msg:1:args email)), 'u@h';
    assert_equals conn_call($db, qw(hget mqueue:msg:1:args user)), 'tt';
    assert_equals conn_call($db, qw(hget mqueue:msg:1:args confirmlink)), 'url/confirm.cgi?key=MTAwMiyOCD5qhk5r83gESdGzGW9K&mail=u@h';
    assert_equals conn_call($db, qw(llen mqueue:msg:1:attach)), 0;
    assert_set_equals conn_call($db, qw(smembers mqueue:msg:1:to)), ['mail:u@h'];
    # - set
    assert_set_equals conn_call($db, qw(smembers mqueue:sending)), [1];
    # - uniqid
    assert_list_equals conn_call($db, qw(hgetall mqueue:uniqid)), ['confirmation-u@h' => 1];
};

# TestServerMailoutMailQueue::testConfirmSuccess: Test CONFIRM, success case.
test 'mailout/50_mailqueue/confirm/success', sub {
    my $setup = shift; 
    setup_add_db($setup); 
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'www.key', '');
    setup_start_wait($setup);

    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hset user:1002:profile email u@h));

    # Confirm
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, qw(confirm u@h MTAwMiyOCD5qhk5r83gESdGzGW9K info));

    # Verify
    assert_equals conn_call($db, qw(hget email:u@h:status status/1002)), 'c';
    assert_equals conn_call($db, qw(hget email:u@h:status confirm/1002)), 'info';

    my %info = conn_call_list($mc, qw(status 1002));
    assert_equals $info{address}, 'u@h';
    assert_equals $info{status}, 'c';
};

# TestServerMailoutMailQueue::testConfirmFailure: Test CONFIRM, failure case.
test 'mailout/50_mailqueue/confirm/failure', sub {
    my $setup = shift; 
    setup_add_db($setup); 
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'www.key', '');
    setup_start_wait($setup);

    #Confirm
    my $mc = setup_connect_app($setup, 'mailout');
    assert_throws sub{ conn_call($mc, qw(confirm u@h MTAwMiyOCD5qhk5r83gESdGWRONG info)) }, 401;
};
