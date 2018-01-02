#!/usr/bin/perl -w
#
#  Talk: TalkNNTP
#
#  Synced with TestServerTalkTalkNNTP, 20170924
#  Fails with c2talk-classic.
#  - nntpuser seems to have a problem with checking MD5's
#    (as -ng is in production for a while now, I'm not going to track this down)
#  - nntpfindng requires user context
#
use strict;
use c2systest;

# TestServerTalkTalkNNTP::testLogin: Test login
test 'talk/50_nntp/login', sub {
    my $setup = shift;
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);

    my $preload_db = sub {
        my $setup = shift;
        my $db = setup_connect_app($setup, 'db');
        conn_call($db, 'set', 'user:1009:password', '1,52YluJAXWKqqhVThh22cNw');
        conn_call($db, 'set', 'uid:a_b', '1009');
        conn_call($db, 'set', 'uid:root', '0');
    };

    # First test
    {
        setup_add_service_config($setup, 'user.key', 'xyz');
        setup_start_wait($setup);
        $preload_db->($setup);
        my $tc = setup_connect_app($setup, 'talk');

        # Success cases
        assert_equals conn_call($tc, 'nntpuser', 'a_b', 'z'), 1009;
        assert_equals conn_call($tc, 'nntpuser', 'A_B', 'z'), 1009;
        assert_equals conn_call($tc, 'nntpuser', 'A->B', 'z'), 1009;

        # Error cases
        assert_throws sub{ conn_call($tc, 'nntpuser', 'root', '')    }, 401;
        assert_throws sub{ conn_call($tc, 'nntpuser', 'a_b',  '')    }, 401;
        assert_throws sub{ conn_call($tc, 'nntpuser', 'a_b',  'zzz') }, 401;
        assert_throws sub{ conn_call($tc, 'nntpuser', 'a_b',  'Z')   }, 401;
        assert_throws sub{ conn_call($tc, 'nntpuser', '',     'Z')   }, 401;
        assert_throws sub{ conn_call($tc, 'nntpuser', '/',    'Z')   }, 401;

        # User context does not change outcome
        conn_call($tc, 'user', 'a');
        assert_equals conn_call($tc, 'nntpuser', 'a_b', 'z'), 1009;
        assert_throws sub{ conn_call($tc, 'nntpuser', 'a_b',  'Z')   }, 401;
        setup_stop($setup);
    }

    # Second test, with different user key. This must make the test fail
    {
        setup_add_service_config($setup, 'user.key', 'abc');
        setup_start_wait($setup);
        $preload_db->($setup);
        my $tc = setup_connect_app($setup, 'talk');

        assert_throws sub{ conn_call($tc, 'nntpuser', 'a_b', 'z')    }, 401;
        assert_throws sub{ conn_call($tc, 'nntpuser', 'root', '')    }, 401;
        setup_stop($setup);
    }
};

# TestServerTalkTalkNNTP::testGroups: Test newsgroup access commands: NNTPLIST, NNTPFINDNG, NNTPGROUPLS
test 'talk/50_nntp/groups', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Multiple sessions
    my $user_session = setup_connect_app($setup, 'talk');
    my $other_session = setup_connect_app($setup, 'talk');
    my $root_session = setup_connect_app($setup, 'talk');
    conn_call($user_session, qw(user a));
    conn_call($other_session, qw(user b));

    # Create a group
    conn_call($root_session, qw(groupadd gr name Group));

    # Create some forums
    assert_equals conn_call($root_session, qw(forumadd name Forum_1 readperm u:a newsgroup ng.one parent gr)), 1;
    assert_equals conn_call($root_session, qw(forumadd name Forum_2 readperm all newsgroup ng.two)),           2;
    assert_equals conn_call($root_session, qw(forumadd name Forum_3 readperm all                  parent gr)), 3;

    # Test
    # - NNTPLIST as user a
    my @ngs = conn_call_list($user_session, qw(nntplist));
    assert_equals scalar(@ngs), 2;
    assert $ngs[0];
    assert $ngs[1];

    my %ng1 = @{$ngs[0]};
    my %ng2 = @{$ngs[1]};
    if ($ng1{id} == 2) {
        %ng1 = %ng2;
        %ng2 = @{$ngs[0]};
    }
    assert_equals $ng1{id}, 1;
    assert_equals $ng1{newsgroup}, 'ng.one';
    assert_equals $ng2{id}, 2;
    assert_equals $ng2{newsgroup}, 'ng.two';

    # - NNTPLIST as user b, who can only see ng.two
    @ngs = conn_call_list($other_session, qw(nntplist));
    assert_equals scalar(@ngs), 1;
    assert $ngs[0];

    %ng1 = @{$ngs[0]};
    assert_equals $ng1{id}, 2;
    assert_equals $ng1{newsgroup}, 'ng.two';

    # - NNTPLIST as root is not allowed
    assert_throws sub{ conn_call($root_session, qw(nntplist)) }, 403;

    # - NNTPFINDNG
    # -- user a
    %ng1 = conn_call_list($user_session, qw(nntpfindng ng.one));
    assert_equals $ng1{id}, 1;
    %ng1 = conn_call_list($user_session, qw(nntpfindng ng.two));
    assert_equals $ng1{id}, 2;
    assert_throws sub{ conn_call_list($user_session, qw(nntpfindng ng.three)) }, 404;

    # -- root
    assert_throws sub{ conn_call_list($root_session, qw(nntpfindng ng.one)) }, 403;
    assert_throws sub{ conn_call_list($root_session, qw(nntpfindng ng.two)) }, 403;
    assert_throws sub{ conn_call_list($root_session, qw(nntpfindng ng.three)) }, 403;

    # -- other user
    assert_throws sub{ conn_call_list($other_session, qw(nntpfindng ng.one)) }, 403;
    %ng1 = conn_call_list($other_session, qw(nntpfindng ng.two));
    assert_equals $ng1{id}, 2;
    assert_throws sub{ conn_call_list($other_session, qw(nntpfindng ng.three)) }, 404;

    # - NNTPGROUPLS
    # FIXME: this command will produce newsgroup names irrespective of accessibility and presence of a newsgroup.
    my @root_result  = sort (conn_call_list($root_session, qw(nntpgroupls gr)));
    my @other_result = sort (conn_call_list($other_session, qw(nntpgroupls gr)));
    assert_equals join(',', @root_result), ',ng.one';
    assert_equals join(',', @other_result), ',ng.one';
};

# TestServerTalkTalkNNTP::testFindMessage: NNTPFINDMID
test 'talk/50_nntp/findmid', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'talk.msgid', '@host');
    setup_start_wait($setup);

    # Create a forum and messages in it
    my $tc = setup_connect_app($setup, 'talk');
    assert_equals conn_call($tc, qw(forumadd)), 1;
    assert_equals conn_call($tc, qw(postnew 1 subj text user a)), 1;
    assert_equals conn_call($tc, qw(postreply 1 subj2 text2 user a)), 2;

    # FIXME: normally, we should be able to set the Message-Id in POSTNEW. For now, work around
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hset msg:2:header msgid mid@otherhost));
    conn_call($db, qw(set msgid:mid@otherhost 2));

    # Test
    assert_equals conn_call($tc, qw(nntpfindmid 1.1@host)), 1;
    assert_equals conn_call($tc, qw(nntpfindmid mid@otherhost)), 2;

    assert_throws sub{ conn_call($tc, qw(nntpfindmid 2.1@host)) }, 404;
    assert_throws sub{ conn_call($tc, qw(nntpfindmid 2.2@host)) }, 404;
    assert_throws sub{ conn_call($tc, qw(nntpfindmid 1.2@host)) }, 404;
    assert_throws sub{ conn_call($tc, 'nntpfindmid', '') }, 404;
};


# TestServerTalkTalkNNTP::testListMessages: NNTPFORUMLS
test 'talk/50_nntp/forumls', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'talk.msgid', '@host');
    setup_start_wait($setup);

    # Two sessions
    my $root_session = setup_connect_app($setup, 'talk');
    my $user_session = setup_connect_app($setup, 'talk');
    conn_call($user_session, qw(user a));

    # Create a forum and messages in it
    assert_equals conn_call($root_session, qw(forumadd name forum writeperm all readperm all)), 1;
    assert_equals conn_call($user_session, qw(postnew 1 subj  text)), 1;
    assert_equals conn_call($user_session, qw(postnew 1 subj2 text2)), 2;
    assert_equals conn_call($user_session, qw(postreply 2 re:subj2 text3)), 3;
    conn_call($user_session, qw(postedit 2 subj2 edit));

    # Test
    # - Result is list of (sequence,post Id), sorted by sequence numbers.
    my @result = conn_call_list($user_session, qw(nntpforumls 1));
    assert_equals join(',', @result), '1,1,3,3,4,2';

    # - Same thing as root
    @result = conn_call_list($root_session, qw(nntpforumls 1));
    assert_equals join(',', @result), '1,1,3,3,4,2';

    # Error case
    assert_throws sub{ conn_call($user_session, qw(nntpforumls 9)) }, 404;
};

# TestServerTalkTalkNNTP::testMessageHeader: NNTPPOST[M]HEAD
test 'talk/50_nntp/posthead', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_service_config($setup, 'talk.msgid', '@host');
    setup_start_wait($setup);

    # Two sessions
    my $root_session = setup_connect_app($setup, 'talk');
    my $user_session = setup_connect_app($setup, 'talk');
    conn_call($user_session, qw(user a));

    # Create a forum and messages in it
    assert_equals conn_call($root_session, qw(forumadd name forum writeperm all readperm all newsgroup ng.name)), 1;
    assert_equals conn_call($user_session, qw(postnew 1 subj  text)), 1;
    assert_equals conn_call($user_session, qw(postnew 1 subj2 text2)), 2;
    assert_equals conn_call($user_session, qw(postreply 2 re:subj2 text3)), 3;
    conn_call($user_session, qw(postedit 2 subj2 edit));

    # Get single header
    my %p = conn_call_list($user_session, qw(nntpposthead 1));
    assert_equals $p{Newsgroups}, 'ng.name';
    assert_equals $p{Subject}, 'subj';
    assert_equals $p{'Message-Id'}, '<1.1@host>';

    %p = conn_call_list($user_session, qw(nntpposthead 2));
    assert_equals $p{Newsgroups}, 'ng.name';
    assert_equals $p{Subject}, 'subj2';
    assert_equals $p{'Message-Id'}, '<2.4@host>';
    assert_equals $p{Supersedes}, '<2.2@host>';

    # Get multiple
    my @ps = conn_call_list($user_session, qw(nntppostmhead 1 9 2));
    assert_equals scalar(@ps), 3;
    assert $ps[0];
    assert !$ps[1];
    assert $ps[2];

    assert_equals {@{$ps[0]}}->{'Message-Id'}, '<1.1@host>';
    assert_equals {@{$ps[2]}}->{'Message-Id'}, '<2.4@host>';
    assert_equals {@{$ps[2]}}->{'Supersedes'}, '<2.2@host>';

    # Error case: must have user context
    assert_throws sub{ conn_call($root_session, qw(nntpposthead 1)) }, 403;
    assert_throws sub{ conn_call($root_session, qw(nntppostmhead 1 3)) }, 403;

    # Error case: does not exist
    assert_throws sub{ conn_call($user_session, qw(nntpposthead 99)) }, 404;
};
