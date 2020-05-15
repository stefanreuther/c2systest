#!/usr/bin/perl -w
#
#  Test message cleanup
#

use strict;
use c2systest;

test 'mailout/07_cleanup/normal', sub {
    # Services
    my $setup = shift;
    prepare($setup);

    # Send a message
    my $mq = setup_connect_app($setup, 'mailout');
    conn_call($mq, 'mail', 'talk-forum', 'post-3003');
    conn_call($mq, 'param', , forum => "Titan 9");
    conn_call($mq, 'param', , posturl => "talk/thread.cgi/490-end-of-game#p3003");
    conn_call($mq, 'param', , subject => "end of game");
    conn_call($mq, 'send', 'user:1240', 'user:1254', 'user:1259');

    # Run queue
    # -- this includes the cleanup we want to test --
    conn_call($mq, 'runqueue');

    # Verify: only the message just sent must remain
    my $db = setup_connect_app($setup, 'db');
    assert_list_equals conn_call($db, 'hgetall', 'mqueue:uniqid'), ['post-3003' => 44849];
};

test 'mailout/07_cleanup/interleave', sub {
    # Services
    my $setup = shift;
    prepare($setup);

    # Send a message
    my $mq = setup_connect_app($setup, 'mailout');
    conn_call($mq, 'mail', 'talk-forum', 'post-3003');
    conn_call($mq, 'param', , forum => "Titan 9");
    conn_call($mq, 'param', , posturl => "talk/thread.cgi/490-end-of-game#p3003");
    conn_call($mq, 'param', , subject => "end of game");

    # Run queue
    # -- this includes the cleanup we want to test --
    conn_call($mq, 'runqueue');

    # Verify: list must now be empty
    my $db = setup_connect_app($setup, 'db');
    assert_list_equals conn_call($db, 'hgetall', 'mqueue:uniqid'), [];

    # Finish the message
    conn_call($mq, 'send', 'user:1240', 'user:1254', 'user:1259');
    assert_list_equals conn_call($db, 'hgetall', 'mqueue:uniqid'), ['post-3003' => 44849];
};



# Common preparation
sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'smtp.from', 'fr@m');
    setup_add_service_config($setup, 'smtp.fqdn', 'fqdn');
    setup_add_service_config($setup, 'www.url', 'http://url/');
    setup_add_service_config($setup, 'www.key', 'xyzzy');

    # Start
    setup_start_wait($setup);

    # Configure database
    # (derived from an actual planetscentral.com state)
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'set' , 'mqueue:msg:id', '44848');
    conn_call($db, 'sadd', 'mqueue:sending', '43218');
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-2588mike', 12646);
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-2878828247', 31072);
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-4e7dfdg', 41310);
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-Alexander', 2367);
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-Bernd', 261);
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-Bjoern', 24792);
    conn_call($db, 'hset', 'mqueue:uniqid', 'confirmation-Carsten', 24);
    conn_call($db, 'hset', 'mqueue:uniqid', 'post-3003', 43219);

    foreach (qw(1240 1254 1259)) {
        conn_call($db, 'set', "user:$_:name", "u$_");
        conn_call($db, 'hset', "user:$_:profile", 'email', "$_\@host");
        conn_call($db, 'hset', "email:$_\@host:status", "expire/$_", int(time()/60) + 1000000);
        conn_call($db, 'hset', "email:$_\@host:status", "status/$_", 'r');
    }
}
