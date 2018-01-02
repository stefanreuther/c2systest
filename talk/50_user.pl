#!/usr/bin/perl -w
#
#  Talk: TalkUser
#
#  Synced with TestServerTalkTalkUser, 20170925
#
use strict;
use c2systest;

# TestServerTalkTalkUser::testNewsrc: USERNEWSRC
test 'talk/50_user/newsrc', sub {
    my $setup = shift;
    prepare($setup);

    # Prepare database. We only need the message counter to pass limit checks.
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'set', 'msg:id', 200);

    # Messages [0,7] read, [8,15] unread, [16,23] read
    conn_call($db, 'hset', 'user:1004:forum:newsrc:data', 0, "\xff\0\xff");

    # Testee
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user 1004));

    # Get single values
    assert_equals conn_call($tc, qw(usernewsrc get post 1)), 1;
    assert_equals conn_call($tc, qw(usernewsrc get post 7)), 1;
    assert_equals conn_call($tc, qw(usernewsrc get post 8)), 0;

    # Get multiple values
    assert_equals conn_call($tc, qw(usernewsrc get post 5 6 7 8 9)), '11100';
    assert_equals conn_call($tc, qw(usernewsrc get post 5 8 6 7 9)), '10110';
    assert_equals conn_call($tc, qw(usernewsrc get range 5 9)), '11100';

    # Find
    assert_equals conn_call($tc, qw(usernewsrc firstset post 5 6 7 8 9)), 5;
    assert_equals conn_call($tc, qw(usernewsrc firstclear post 5 6 7 8 9)), 8;
    assert_equals conn_call($tc, qw(usernewsrc firstset range 5 9)), 5;
    assert_equals conn_call($tc, qw(usernewsrc firstclear range 5 9)), 8;

    # Result is first in iteration order, not lowest!
    assert_equals conn_call($tc, qw(usernewsrc firstset post 8 7 6 5 9)), 7;
    assert_equals conn_call($tc, qw(usernewsrc firstclear post 8 7 6 5 9)), 8;

    # Nothing in range
    assert_equals conn_call($tc, qw(usernewsrc firstset range 8 12)), 0;

    # Any/All
    assert_equals conn_call($tc, qw(usernewsrc any post 5 6 7 8 9)), 1;
    assert_equals conn_call($tc, qw(usernewsrc all post 5 6 7 8 9)), 0;
    assert_equals conn_call($tc, qw(usernewsrc any post 8 9 10)), 0;
    assert_equals conn_call($tc, qw(usernewsrc all post 8 9 10)), 0;
    assert_equals conn_call($tc, qw(usernewsrc any post 5 6 7)), 1;
    assert_equals conn_call($tc, qw(usernewsrc all post 5 6 7)), 1;
    assert_equals conn_call($tc, qw(usernewsrc any post 14 15 16)), 1;
    assert_equals conn_call($tc, qw(usernewsrc all post 14 15 16)), 0;

    # Modifications
    # start with 11111110000000011111111
    assert_equals conn_call($tc, qw(usernewsrc get range 1 23)), '11111110000000011111111';

    # Get and mark unread
    assert_equals conn_call($tc, qw(usernewsrc get clear range 6 9)), '1100';
    assert_equals conn_call($tc, qw(usernewsrc get       range 6 9)), '0000';
    assert_equals conn_call($tc, qw(usernewsrc get range 1 23)), '11111000000000011111111';

    # Find and mark read
    assert_equals conn_call($tc, qw(usernewsrc firstclear set range 4 9)), 6;
    assert_equals conn_call($tc, qw(usernewsrc get range 1 23)), '11111111100000011111111';
};

# TestServerTalkTalkUser::testNewsrcErrors: USERNEWSRC errors
test 'talk/50_user/newsrc/errors', sub {
    my $setup = shift;
    prepare($setup);

    # Prepare database. We only need the message counter to pass limit checks.
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(set msg:id 200));

    # Do it
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user 1004));

    assert_throws sub{ conn_call($tc, qw(usernewsrc get range 201 210)) },        qr{404|413};     # ng reports 404, classic reports 413
    assert_throws sub{ conn_call($tc, qw(usernewsrc get post 100 200 201 210)) }, qr{404|413};     # ng reports 404, classic reports 413
};

# TestServerTalkTalkUser::testNewsrcSingle: USERNEWSRC for single elements.
# The point of this test is to validate that the result of single element accesses can be interpreted as an integer.
test 'talk/50_user/newsrc/single', sub {
    my $setup = shift;
    prepare($setup);

    # Prepare database. We only need the message counter to pass limit checks.
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(set msg:id 200));

    # Test
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user 1004));

    # Initial state: unread
    assert_equals conn_call($tc, qw(usernewsrc get post 1)), 0;

    # Mark read
    conn_call($tc, qw(usernewsrc set post 1));

    # Verify
    assert_equals conn_call($tc, qw(usernewsrc get post 1)), 1;

    # Mark unread
    conn_call($tc, qw(usernewsrc clear post 1));

    # Verify
    assert_equals conn_call($tc, qw(usernewsrc get post 1)), 0;
};

# TestServerTalkTalkUser::testNewsrcSet: USERNEWSRC for sets
test 'talk/50_user/newsrc/set', sub {
    my $setup = shift;
    prepare($setup);

    # Preload database
    my $db = setup_connect_app($setup, 'db');

    # - a forum
    conn_call($db, qw(hset forum:2:header name f));
    conn_call($db, qw(sadd forum:all 2));

    # - topic
    conn_call($db, qw(hset thread:42:header subject s));
    conn_call($db, qw(sadd forum:2:threads 42));

    # - messages
    conn_call($db, qw(sadd forum:2:messages), 3 .. 19);
    conn_call($db, qw(sadd thread:42:messages), 3 .. 19);

    # Test
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user 1004));

    # Mark forum read
    conn_call($tc, qw(usernewsrc set forum 2));

    # Find unread in thread
    assert_equals conn_call($tc, qw(usernewsrc firstclear thread 42)), 0;

    # Find read in thread
    assert_equals conn_call($tc, qw(usernewsrc firstset thread 42)), 3;

    # Mark thread unread
    conn_call($tc, qw(usernewsrc clear thread 42));

    # Find read
    assert_equals conn_call($tc, qw(usernewsrc firstset forum 2)), 0;

    # Find unread
    assert_equals conn_call($tc, qw(usernewsrc firstclear forum 2)), 3;
};

# TestServerTalkTalkUser::testRoot: commands as root
test 'talk/50_user/root', sub {
    my $setup = shift;
    prepare($setup);

    # Test must fail, we need a user context
    my $tc = setup_connect_app($setup, 'talk');
    assert_throws sub{ conn_call($tc, qw(usernewsrc)) },           qr{403|401}; # ng returns 403, classic returns 401
    assert_throws sub{ conn_call($tc, qw(userwatch)) },            qr{403|401};
    assert_throws sub{ conn_call($tc, qw(userunwatch)) },          qr{403|401};
    assert_throws sub{ conn_call($tc, qw(usermarkseen)) },         qr{403|401};
    assert_throws sub{ conn_call($tc, qw(userlswatchedthreads)) }, qr{403|401};
    assert_throws sub{ conn_call($tc, qw(userlswatchedforums)) },  qr{403|401};
};

# TestServerTalkTalkUser::testWatch: watch-related commands
test 'talk/50_user/watch', sub {
    my $setup = shift;
    prepare($setup);

    # Populate database
    my $db = setup_connect_app($setup, 'db');
    foreach (8 .. 11) {
        conn_call($db, 'sadd', 'forum:all', $_);
        conn_call($db, 'hset', "forum:$_:header", 'name', 'f');
    }
    foreach (1 .. 19) {
        conn_call($db, 'hset', "thread:$_:header", 'subject', 's');
    }

    # Test
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user 1004));

    # Verify initial state
    assert !conn_call_list($tc, qw(userlswatchedforums));
    assert !conn_call_list($tc, qw(userlswatchedthreads));

    # Watch some things
    conn_call($tc, 'userwatch', 'forum', 9, 'thread', 10, 'forum', 11);

    # Verify new state
    my @r = conn_call_list($tc, qw(userlswatchedforums));
    assert_equals join(',', @r), '9,11';

    @r = conn_call_list($tc, qw(userlswatchedthreads));
    assert_equals join(',', @r), '10';

    # Verify new state
    assert_equals conn_call($tc, qw(userlswatchedforums size)), 2;

    # Mark a topic notified in DB, then unsubscribe it. This should reset the notification.
    conn_call($db, qw(sadd user:1004:forum:notifiedThreads 10));
    conn_call($db, qw(sadd user:1004:forum:notifiedForums 9));
    conn_call($tc, qw(userunwatch forum 9 thread 10));

    assert_equals conn_call($db, qw(sismember user:1004:forum:notifiedThreads 10)), 0;
    assert_equals conn_call($db, qw(sismember user:1004:forum:notifiedForums 9)), 0;

    # Mark a forum notified in DB, then mark it seen.
    conn_call($db, qw(sadd user:1004:forum:notifiedForums 11));
    conn_call($tc, qw(usermarkseen forum 11));
    assert_equals conn_call($db, qw(sismember user:1004:forum:notifiedForums 11)), 0;

    # Error case: cannot access ranges
    assert_throws sub{ conn_call($tc, qw(usermarkseen range 3 9)) }, 400;
    assert_throws sub{ conn_call($tc, qw(userwatch range 3 9)) }, 400;
    assert_throws sub{ conn_call($tc, qw(userunwatch range 3 9)) }, 400;
};

# TestServerTalkTalkUser::testPostedMessages: USERLSPOSTED
test 'talk/50_user/posted', sub {
    my $setup = shift;
    prepare($setup);

    # Preload DB
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd user:1002:forum:posted 9 10 12));

    # Access as root
    my $tc = setup_connect_app($setup, 'talk');
    assert_equals join(',', conn_call_list($tc, qw(userlsposted 1002))), '9,10,12';

    # Access as 1002
    conn_call($tc, qw(user 1002));
    assert_equals join(',', conn_call_list($tc, qw(userlsposted 1002))), '9,10,12';

    # Access as 1009
    conn_call($tc, qw(user 1009));
    assert_equals join(',', conn_call_list($tc, qw(userlsposted 1002))), '9,10,12';
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
}
