#!/usr/bin/perl -w
#
#  Talk: TalkPM
#
#  Synced with TestServerTalkTalkPM, 20170924
#
use strict;
use c2systest;

# TestServerTalkTalkPM::testIt: command tests
test 'talk/50_pm', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Two sessions
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # Make two system folders
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'hset', 'default:folder:1:header', 'name',        'Inbox');
    conn_call($db, 'hset', 'default:folder:1:header', 'description', 'Incoming messages');
    conn_call($db, 'hset', 'default:folder:2:header', 'name',        'Outbox');
    conn_call($db, 'hset', 'default:folder:2:header', 'description', 'Sent messages');
    conn_call($db, 'sadd', 'default:folder:all', 1, 2);

    # Send a message from A to B
    assert_equals conn_call($a, 'pmnew', 'u:b', 'subj', 'text:text'), 1;

    # Send a reply
    assert_equals conn_call($b, 'pmnew', 'u:a', 're: subj', 'text:wtf', 'parent', 1), 2;

    # Get info on #1. It's in A's outbox and B's inbox
    my %i = conn_call_list($a, qw(pmstat 2 1));
    assert_equals $i{author}, 'a';
    assert_equals $i{to}, 'u:b';
    assert_equals $i{subject}, 'subj';
    assert_equals $i{flags}, 1;           # we sent it, that counts as if it is read

    assert_throws sub{ conn_call($a, qw(pmstat 1 1)) }, 404;

    %i = conn_call_list($b, 'pmstat', 1, 1);
    assert_equals $i{author}, 'a';
    assert_equals $i{to}, 'u:b';
    assert_equals $i{subject}, 'subj';
    assert_equals $i{flags}, 0;

    # Copy. Message #1 is in A's outbox, #2 is in his inbox. Copy #2 into outbox as well.
    # Result is number of messages copied. Only #2 is in inbox.
    assert_equals conn_call($a, qw(pmcp 1 2 1 2 9)), 1;

    # Copying again does not change the result.
    assert_equals conn_call($a, qw(pmcp 1 2 1 2 9)), 1;

    # Self-copy: both messages are in source.
    assert_equals conn_call($a, qw(pmcp 2 2 1 2 9)), 2;

    # Verify that refcount is not broken.
    # Message #1 is in A's outbox and B's inbox.
    # Message #2 is in A's in+outbox and B's outbox.
    assert_equals conn_call($db, qw(hget pm:1:header ref)), 2;
    assert_equals conn_call($db, qw(hget pm:2:header ref)), 3;

    # Multi-get
    my @is = conn_call_list($a, qw(pmmstat 2 1 2 9));
    assert_equals scalar(@is), 3;
    assert $is[0];
    assert $is[1];
    assert !$is[2];

    assert_equals {@{$is[0]}}->{author}, 'a';
    assert_equals {@{$is[1]}}->{author}, 'b';

    # Move.
    # Result is number of messages moved. Only #2 is in A's inbox.
    assert_equals conn_call($a, qw(pmmv 1 2 1 2 9)), 1;

    # Move again. Inbox now empty, so result is 0.
    assert_equals conn_call($a, qw(pmmv 1 2 1 2 9)), 0;

    # Verify that refcount is not broken.
    # Message #1 is in A's outbox and B's inbox.
    # Message #2 is in A's outbox and B's outbox.
    assert_equals conn_call($db, qw(hget pm:1:header ref)), 2;
    assert_equals conn_call($db, qw(hget pm:2:header ref)), 2;

    # Self-move is a no-op.
    assert_equals conn_call($a, qw(pmmv 2 2 1 2 9)), 2;
    assert_equals conn_call($db, qw(hget pm:1:header ref)), 2;
    assert_equals conn_call($db, qw(hget pm:2:header ref)), 2;

    # Remove
    # Message #1 is in A's outbox and B's inbox.
    assert_equals conn_call($a, qw(pmrm 1 1 7)), 0;
    assert_equals conn_call($a, qw(pmrm 2 1 7)), 1;
    assert_equals conn_call($b, qw(pmrm 1 1 7)), 1;
    assert_equals conn_call($b, qw(pmrm 2 1 7)), 0;
    assert !conn_call($db, qw(hget pm:1:header ref));      # C++ version tests against 0; Perl version has no automatic undefined->0 conversion

    # Render
    assert_equals conn_call($a, qw(pmrender 2 2 format html)), "<p>wtf</p>\n";
    assert_equals conn_call($b, qw(pmrender 2 2 format html)), "<p>wtf</p>\n";
    assert_throws sub{ conn_call($b, qw(pmrender 1 2 format html)) }, 404;

    my @result = conn_call_list($a, qw(pmmrender 2 5 2));
    assert_equals scalar(@result), 2;
    assert !$result[0];
    assert_equals $result[1], "text:wtf";      # default state is type "raw"

    # Flags
    # Verify initial state
    assert_equals {conn_call_list($a, qw(pmstat 2 2))}->{flags}, 0;
    assert_equals {conn_call_list($b, qw(pmstat 2 2))}->{flags}, 1;

    # Change flags
    assert_equals conn_call($a, qw(pmflag 2 1 4 2)), 1;     # A's outbox
    assert_equals conn_call($b, qw(pmflag 2 0 8 2)), 1;     # B's outbox
    assert_equals conn_call($b, qw(pmflag 1 0 8 2)), 0;     # wrong folder

    assert_equals {conn_call_list($a, qw(pmstat 2 2))}->{flags}, 4;
    assert_equals {conn_call_list($b, qw(pmstat 2 2))}->{flags}, 9;
};

# TestServerTalkTalkPM::testRoot: Command tests for root. Must all fail.
test 'talk/50_pm/root', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Make system folders (not required, commands hopefully fail before looking here)
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(hset default:folder:1:header name Inbox));
    conn_call($dbc, qw(sadd default:folder:all 1));

    # Testee
    my $tc = setup_connect_app($setup, 'talk');
    assert_throws sub{ conn_call($tc, qw(pmnew u:a subj text:text)) }, 403;
    assert_throws sub{ conn_call($tc, qw(pmstat 1 42)) },              403;
    assert_throws sub{ conn_call($tc, qw(pmmstat 1 1 3 5)) },          403;
    assert_throws sub{ conn_call($tc, qw(pmcp 1 2 1 3 5)) },           403;
    assert_throws sub{ conn_call($tc, qw(pmmv 1 2 1 3 5)) },           403;
    assert_throws sub{ conn_call($tc, qw(pmrm 1 1 3 5)) },             403;
    assert_throws sub{ conn_call($tc, qw(pmrender 1 42)) },            403;
    assert_throws sub{ conn_call($tc, qw(pmmrender 1 1 3 5)) },        403;
    assert_throws sub{ conn_call($tc, qw(pmflag 1 4 8 1 3 5)) },       403;
};

# TestServerTalkTalkPM::testReceivers: Test receiver handling
test 'talk/50_pm/receivers', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Connect as user
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user a));

    # Preload database
    my $db = setup_connect_app($setup, 'db');
    # - users b,c,d are on game 3
    conn_call($db, qw(sadd game:all 3));
    conn_call($db, qw(hset game:3:users b 1));
    conn_call($db, qw(hset game:3:users c 1));
    conn_call($db, qw(hset game:3:users d 1));

    # - user b is fed, c is robot together with b
    conn_call($db, qw(rpush game:3:player:1:users b));
    conn_call($db, qw(rpush game:3:player:9:users c));
    conn_call($db, qw(rpush game:3:player:9:users b));

    # Sending mails, successful cases
    assert_equals conn_call($tc, 'pmnew', 'u:b',       'subj', 'text:text'), 1;
    assert_equals conn_call($tc, 'pmnew', 'g:3',       'subj', 'text:text'), 2;
    assert_equals conn_call($tc, 'pmnew', 'g:3:1',     'subj', 'text:text'), 3;
    assert_equals conn_call($tc, 'pmnew', 'g:3:9',     'subj', 'text:text'), 4;
    assert_equals conn_call($tc, 'pmnew', 'g:3:9,u:d', 'subj', 'text:text'), 5;
    assert_equals conn_call($tc, 'pmnew', 'u:b,u:a',   'subj', 'text:text'), 6;

    # Verify mails
    # - a has everything in their outbox, and one in their inbox
    assert join(',', conn_call_list($db, qw(sort user:a:pm:folder:1:messages))), '6';
    assert join(',', conn_call_list($db, qw(sort user:a:pm:folder:2:messages))), '1,2,3,4,5,6';
    
    # - b has everything in their inbox
    assert join(',', conn_call_list($db, qw(sort user:b:pm:folder:1:messages))), '1,2,3,4,5,6';

    # - c has just messages 2, 4, 5
    assert join(',', conn_call_list($db, qw(sort user:c:pm:folder:1:messages))), '2,4,5';

    # - d has just messages 2, 5
    assert join(',', conn_call_list($db, qw(sort user:d:pm:folder:1:messages))), '2,5';
};

# TestServerTalkTalkPM::testReceiverErrors: Test receiver errors.
test 'talk/50_pm/receivererrors', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Connect as user
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user a));

    # Preload database
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd game:all 3));

    # Failure: expands to no users
    assert_throws sub{ conn_call($tc, qw(pmnew g:3 subj text:text)) }, 412;
    assert_throws sub{ conn_call($tc, qw(pmnew g:3:1 subj text:text)) }, 412;

    # Failure: range error
    assert_throws sub{ conn_call($tc, qw(pmnew g:9 subj text:text)) }, 400;
    assert_throws sub{ conn_call($tc, qw(pmnew g:0 subj text:text)) }, 400;
    assert_throws sub{ conn_call($tc, qw(pmnew g:3:0 subj text:text)) }, 400;
    assert_throws sub{ conn_call($tc, qw(pmnew g:3:20 subj text:text)) }, 400;

    # Failure: parse error
    assert_throws sub{ conn_call($tc, 'pmnew', '',         'subj', 'text:text') }, 400;
    assert_throws sub{ conn_call($tc, 'pmnew', 'u:a,',     'subj', 'text:text') }, 400;
    assert_throws sub{ conn_call($tc, 'pmnew', 'u:a, u:b', 'subj', 'text:text') }, 400;
    assert_throws sub{ conn_call($tc, 'pmnew', 'u:a,,u:b', 'subj', 'text:text') }, 400;
    assert_throws sub{ conn_call($tc, 'pmnew', 'x:1',      'subj', 'text:text') }, 400;
};

