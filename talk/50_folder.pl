#!/usr/bin/perl -w
#
#  Talk: TalkFolder
#
#  Synced with TestServerTalkTalkFolder, 20170923
#
use strict;
use c2systest;

# TestServerTalkTalkFolder::testIt: test folder commands
test 'talk/50_folder', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Make two system folders
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'hmset', 'default:folder:1:header', 'name', 'Inbox', 'description', 'Incoming messages');
    conn_call($dbc, 'hmset', 'default:folder:2:header', 'name', 'Outbox', 'description', 'Sent messages');
    conn_call($dbc, 'sadd', 'default:folder:all', 1, 2);

    # Testee
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user a));

    # Create a user folder
    assert_equals conn_call($tc, 'FOLDERNEW', 'mine', 'description', 'My stuff'), 100;

    # Get folders
    my @fs = sort {$a<=>$b} conn_call_list($tc, 'FOLDERLS');
    assert_equals join(',',@fs), '1,2,100';

    # Configure
    conn_call($tc, 'FOLDERSET', 1, 'name', 'New Mail', 'description', 'Incoming');

    # Get info
    my %i = conn_call_list($tc, 'FOLDERSTAT', 1);
    assert_equals $i{name}, 'New Mail';
    assert_equals $i{description}, 'Incoming';
    assert_equals $i{messages}, 0;
    assert_equals $i{fixed}, 1;

    %i = conn_call_list($tc, 'FOLDERSTAT', 100);
    assert_equals $i{name}, 'mine';
    assert_equals $i{description}, 'My stuff';
    assert_equals $i{messages}, 0;
    assert_equals $i{fixed}, 0;

    assert_throws sub{ conn_call($tc, 'FOLDERSTAT', 200) }, 404;

    # Multi-info
    my @is = conn_call_list($tc, 'FOLDERMSTAT', 1, 100, 200, 2);
    assert_equals scalar(@is), 4;
    assert $is[0];
    assert $is[1];
    assert !$is[2];
    assert $is[3];

    %i = @{$is[0]}; assert_equals $i{name}, 'New Mail';
    %i = @{$is[1]}; assert_equals $i{name}, 'mine';
    %i = @{$is[3]}; assert_equals $i{name}, 'Outbox';

    # Link some PMs for further use
    conn_call($dbc, qw(sadd user:a:pm:folder:2:messages 42));
    conn_call($dbc, qw(sadd user:a:pm:folder:100:messages 42));
    conn_call($dbc, qw(hset pm:42:header ref 2));

    # Get PMs
    my @pms = conn_call_list($tc, 'FOLDERLSPM', 2);
    assert_equals join(',',@pms), '42';

    assert_throws sub{ conn_call($tc, 'FOLDERLSPM', 200) }, 404;

    # Remove
    assert_equals conn_call($tc, 'FOLDERRM', 100), 1;
    assert_equals conn_call($tc, 'FOLDERRM', 100), 0;
    assert_equals conn_call($tc, 'FOLDERRM', 1), 0;
    assert_equals conn_call($dbc, qw(hget pm:42:header ref)), 1;

    # Error cases [must be at end because they might be partially executed]
    # @change Classic returns "too few arguments", ng returns 400.
    assert_throws sub{ conn_call($tc, 'FOLDERNEW', 'more', 'description') };
    assert_throws sub{ conn_call($tc, 'FOLDERSET', 1, 'description') };
};

# TestServerTalkTalkFolder::testRoot: Test commands as root. Must all fail because we need a user context.
test 'talk/50_folder/root', sub {
    # Infrastructure
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Make a system folders (not required, commands hopefully fail before looking here)
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'hmset', 'default:folder:1:header', 'name', 'Inbox');
    conn_call($dbc, 'sadd', 'default:folder:all', 1);

    # Tests
    my $tc = setup_connect_app($setup, 'talk');
    assert_throws sub{ conn_call($tc, 'FOLDERLS') },         403;
    assert_throws sub{ conn_call($tc, 'FOLDERSTAT', 1) },    403;
    assert_throws sub{ conn_call($tc, 'FOLDERMSTAT', 1) },   403;
    assert_throws sub{ conn_call($tc, 'FOLDERNEW', 'foo') }, 403;
    assert_throws sub{ conn_call($tc, 'FOLDERRM', 100) },    403;
    assert_throws sub{ conn_call($tc, 'FOLDERSET', 1) },     403;
    assert_throws sub{ conn_call($tc, 'FOLDERLSPM', 1) },    403;
};
