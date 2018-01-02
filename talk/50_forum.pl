#!/usr/bin/perl -w
#
#  Talk: TalkForum
#
#  Synced with TestServerTalkTalkForum, 20170923
#  Fails with c2talk-classic.
#
use strict;
use c2systest;

# TestServerTalkTalkForum::testIt: test commands
test 'talk/50_forum', sub {
    my $setup = shift;
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create two sessions
    my $root_tc = setup_connect_app($setup, 'talk');
    my $user_tc = setup_connect_app($setup, 'talk');
    conn_call($user_tc, qw(user a));

    # Create two groups [for testing]
    conn_call($root_tc, qw(groupadd g1 name N1));
    conn_call($root_tc, qw(groupadd g2 name N2));

    # Create first forums
    assert_equals conn_call($root_tc, qw(forumadd name First parent g1 newsgroup ng.first readperm all writeperm u:b)), 1;

    # Create second forum
    # - Try to create as user, must fail
    assert_throws sub{ conn_call($user_tc, qw(forumadd name Second)) }, 403;

    # - As admin
    assert_equals conn_call($root_tc, qw(forumadd name Second readperm all writeperm all)), 2;

    # - Verify group content
    my %group = conn_call_list($user_tc, qw(groupls g1));
    assert_equals join(',', @{$group{forums}}), '1';

    # Configure forums
    conn_call($root_tc, qw(forumset 1 parent g2));

    # - Verify
    %group = conn_call_list($user_tc, qw(groupls g1));
    assert_equals join(',', @{$group{forums}}), '';

    # - Verify
    %group = conn_call_list($user_tc, qw(groupls g2));
    assert_equals join(',', @{$group{forums}}), '1';

    # - Errors
    assert_throws sub{ conn_call($root_tc, qw(forumset 5 parent g2)) }, 404;
    assert_throws sub{ conn_call($user_tc, qw(forumset 1 parent g2)) }, 403;
    assert_throws sub{ conn_call($root_tc, qw(forumset 1 parent)) }, 400;

    # Get configuration
    assert_equals conn_call($root_tc, qw(forumget 2 readperm)), 'all';
    assert_throws sub{ conn_call($root_tc, qw(forumget 9 readperm)) }, 404;

    # Get information
    # - ok, ask first as user
    my %info = conn_call_list($user_tc, qw(forumstat 1));
    assert_equals $info{name}, 'First';
    assert_equals $info{parent}, 'g2';
    assert_equals $info{description}, '';
    assert_equals $info{newsgroup}, 'ng.first';

    # - ok, ask second as root
    %info = conn_call_list($root_tc, qw(forumstat 2));
    assert_equals $info{name}, 'Second';
    assert_equals $info{parent}, '';
    assert_equals $info{description}, '';
    assert_equals $info{newsgroup}, '';

    # - error case
    assert_throws sub{ conn_call($user_tc, qw(forumstat 10)) }, 404;

    # - ask multiple
    my @infos = conn_call_list($user_tc, qw(forummstat 1 2));
    assert_equals scalar(@infos), 2;
    assert $infos[0];
    assert $infos[1];
    %info = @{$infos[0]};
    assert_equals $info{name}, 'First';
    %info = @{$infos[1]};
    assert_equals $info{name}, 'Second';

    # - ask multiple, including invalid
    # FIXME: this is consistent with PCC2, but inconsistent with other get-multiple commands that return a null pointer for failing items
    assert_throws sub{ conn_call($user_tc, qw(forummstat 1 10 2)) }, 404;

    # Get permissions
    assert_equals conn_call($root_tc, qw(forumperms 1 write read)), 3;
    assert_equals conn_call($user_tc, qw(forumperms 1 write read)), 2;
    assert_equals conn_call($user_tc, qw(forumperms 1 read write)), 1;
    assert_throws sub{ conn_call($user_tc, qw(forumperms 10 write read)) }, 404;

    # Get size
    # - initially empty
    %info = conn_call_list($user_tc, qw(forumsize 2));
    assert_equals $info{threads}, 0;
    assert_equals $info{stickythreads}, 0;
    assert_equals $info{messages}, 0;

    # - create one topic with two posts
    assert_equals conn_call($user_tc, 'postnew', 2, 'subj', 'text:text'), 1;
    assert_equals conn_call($user_tc, 'postreply', 1, 'Re: subj', 'text:witty reply'), 2;

    # - no longer empty
    %info = conn_call_list($user_tc, qw(forumsize 2));
    assert_equals $info{threads}, 1;
    assert_equals $info{stickythreads}, 0;
    assert_equals $info{messages}, 2;

    # - error case
    assert_throws sub{ conn_call($user_tc, qw(forumsize 9)) }, 404;

    # Get content. Let's keep this simple.
    assert_equals join(',', conn_call_list($user_tc, qw(forumlsthread 2))), '1';
    assert_equals join(',', conn_call_list($user_tc, qw(forumlssticky 2))), '';
    assert_equals join(',', conn_call_list($user_tc, qw(forumlspost 2))), '1,2';

    # - error cases
    assert_throws sub{ conn_call($user_tc, qw(forumlsthread 7)) }, 404;
    assert_throws sub{ conn_call($user_tc, qw(forumlssticky 7)) }, 404;
    assert_throws sub{ conn_call($user_tc, qw(forumlspost 7)) }, 404;
}
