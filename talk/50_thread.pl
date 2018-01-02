#!/usr/bin/perl -w
#
#  Talk: TalkThread
#
#  Synced with TestServerTalkTalkThread, 20170925
#
use strict;
use c2systest;


# TestServerTalkTalkThread::testIt
test 'talk/50_thread', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Connect
    my $root = setup_connect_app($setup, 'talk');
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # Create some forums
    assert_equals conn_call($root, qw(forumadd name forum1 readperm all deleteperm u:b writeperm all)), 1;
    assert_equals conn_call($root, qw(forumadd name forum2 readperm all)), 2;

    # Create messages by posting stuff
    # - Thread 1
    assert_equals conn_call($a, 'postnew', 1, 'subj', 'text:content'), 1;
    assert_equals conn_call($a, 'postreply', 1, 're: subj', 'text:more'), 2;
    assert_equals conn_call($a, 'postreply', 1, 're: subj', 'text:more'), 3;
    assert_equals {conn_call_list($a, 'poststat', 2)}->{thread}, 1;

    # - Thread 2
    assert_equals conn_call($a, 'postnew', 1, 'subj2', 'text:content'), 4;
    assert_equals conn_call($a, 'postreply', 4, 're: subj2', 'text:more'), 5;
    assert_equals conn_call($a, 'postreply', 5, 're: re: subj2', 'text:more'), 6;
    assert_equals {conn_call_list($a, 'poststat', 4)}->{thread}, 2;

    ##
    ##  Test as user
    ##

    # THREADSTAT
    # - ok case
    my %i = conn_call_list($a, 'threadstat', 1);
    assert_equals $i{subject}, 'subj';
    assert_equals $i{forum}, 1;
    assert_equals $i{firstpost}, 1;
    assert_equals $i{lastpost}, 3;
    assert !$i{sticky};          # classic returns undef, ng returns 0

    # - error case
    assert_throws sub{ conn_call($a, 'threadstat', 99) }, 404;

    # THREADMSTAT
    my @is = conn_call_list($a, 'threadmstat', 2, 9, 1);
    assert_equals scalar(@is), 3;
    assert $is[0];
    assert !$is[1];
    assert $is[2];
    assert_equals {@{$is[0]}}->{subject}, 'subj2';
    assert_equals {@{$is[2]}}->{subject}, 'subj';

    # - boundary case
    @is = conn_call_list($a, 'threadmstat');
    assert_equals scalar(@is), 0;

    # THREADLSPOST
    my @ps = conn_call_list($a, 'threadlspost', 2);
    assert_equals join(',', @ps), '4,5,6';

    # Stickyness
    # Error case: user a does not have permission
    assert_throws sub{ conn_call($a, 'threadsticky', 1, 1) }, 403;

    # Error case: nonexistant thread
    assert_throws sub{ conn_call($a,    'threadsticky', 3, 1) }, 404;
    assert_throws sub{ conn_call($root, 'threadsticky', 3, 1) }, 404;
    
    # Success case: root can do it [repeatedly]
    conn_call($root, 'threadsticky', 1, 1);
    conn_call($root, 'threadsticky', 1, 1);

    # Verify
    assert_equals conn_call($root, 'forumlssticky', 1, 'contains', 1), 1;

    # Success case: b can do it
    conn_call($b, 'threadsticky', 1, 0);
    conn_call($b, 'threadsticky', 1, 0);
    assert_equals conn_call($root, 'forumlssticky', 1, 'contains', 1), 0;

    # Get permissions
    # root can do anything
    assert_equals conn_call($root, 'threadperms', 1, 'write', 'delete'), 3;

    # a can write but not delete
    assert_equals conn_call($a, 'threadperms', 1, 'write', 'delete'), 1;

    # b can write and delete
    assert_equals conn_call($b, 'threadperms', 1, 'write', 'delete'), 3;

    # Move
    # - Error cases: users cannot do this due to missing permissions
    assert_throws sub{ conn_call($a, 'threadmv', 1, 2) }, 403;
    assert_throws sub{ conn_call($b, 'threadmv', 1, 2) }, 403;

    # - Error case: bad Ids
    assert_throws sub{ conn_call($root, 'threadmv', 55, 2) }, 404;
    assert_throws sub{ conn_call($root, 'threadmv', 1, 55) }, 404;

    # - OK case, null operation
    conn_call($a, 'threadmv', 1, 1);
    conn_call($b, 'threadmv', 1, 1);

    # - OK case
    conn_call($root, 'threadmv', 1, 2);

    # - Verify
    assert_equals {conn_call_list($a, 'threadstat', 1)}->{forum}, 2;

    # Remove
    # - Error case: a cannot remove
    assert_throws sub{ conn_call($a, 'threadrm', 1) }, 403;
    assert_throws sub{ conn_call($a, 'threadrm', 2) }, 403;

    # - Error case: b cannot remove #1 from forum #2
    assert_throws sub{ conn_call($b, 'threadrm', 1) }, 403;

    # - Not-quite-error case: does not exist
    assert_equals conn_call($a, 'threadrm', 99), 0;
    assert_equals conn_call($b, 'threadrm', 99), 0;
    assert_equals conn_call($root, 'threadrm', 99), 0;

    # - Success case: root can remove thread #1
    assert_equals conn_call($root, 'threadrm', 1), 1;
    assert_equals conn_call($root, 'threadrm', 1), 0;

    # - Success case: b can remove thread #2 from forum #1
    assert_equals conn_call($b, 'threadrm', 2), 1;
    assert_equals conn_call($b, 'threadrm', 2), 0;
};
