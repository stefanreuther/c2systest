#!/usr/bin/perl -w
#
#  Talk: TalkPost
#
#  Synced with TestServerTalkTalkPost, 20170924
#  Fails with c2talk-classic (different error messages).
#
use strict;
use c2systest;

# TestServerTalkTalkPost::testCreate: omitted, it is intercepting mailout which we cannot do
# TestServerTalkTalkPost::testCreateSpam: omitted for simplicity

# TestServerTalkTalkPost::testCreateErrors: POSTNEW, error cases
test 'talk/50_post/new/errors', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header writeperm all readperm all name Foorum));

    # Testee
    my $tc = setup_connect_app($setup, 'talk');

    # Error: posting from admin context without USER
    assert_throws sub{ conn_call($tc, qw(postnew 42 subj text)) }, 403;

    # Error: posting from user context with USER
    conn_call($tc, qw(user a));
    assert_throws sub{ conn_call($tc, qw(postnew 42 subj text user u)) }, 403;

    # Error: posting into nonexistant forum
    assert_throws sub{ conn_call($tc, qw(postnew 43 subj text)) }, 404;
};

# TestServerTalkTalkPost::testPermissions: Test permissions in POSTNEW, POSTREPLY, POSTEDIT
test 'talk/50_post/perms', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header readperm all name Foorum));
    conn_call($db, 'hset', 'forum:42:header', 'writeperm', '-u:b,all');

    # Connections for three users
    my $root = setup_connect_app($setup, 'talk');
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # - Plain create fails because we didn't set a user
    assert_throws sub{ conn_call($root, qw(postnew 42 subj text)) }, 403;

    # - Normal posting (#1)
    assert_equals conn_call($root, qw(postnew 42 subj text:text user a)), 1;
    # FIXME: is this correct? -> TS_ASSERT_EQUALS(server::talk::Topic(root, topicId).firstPostingId().get(), topicId);

    # - Normal posting with permissions (#2)
    assert_equals conn_call($root, qw(postnew 42 subj text:text user a answerperm all)), 2;
    # FIXME: is this correct? -> TS_ASSERT_EQUALS(server::talk::Topic(root, topicId).firstPostingId().get(), topicId);

    # - Posting with implicit user permission (#3)
    assert_equals conn_call($a, qw(postnew 42 subj text:text)), 3;
    # FIXME: is this correct? -> TS_ASSERT_EQUALS(server::talk::Topic(root, topicId).firstPostingId().get(), topicId);

    # - Posting with conflicting user permission
    assert_throws sub{ conn_call($a, qw(postnew 42 subj text:text user b)) }, 403;

    # - Posting with matching permission (#4)
    assert_equals conn_call($a, qw(postnew 42 subj text:text user a)), 4;
    # FIXME: is this correct? -> TS_ASSERT_EQUALS(server::talk::Topic(root, topicId).firstPostingId().get(), topicId);

    # - Posting with disallowed user
    assert_throws sub{ conn_call($b, qw(postnew 42 subj text:text)) }, 403;

    # - Posting with root permissions as disallowed user (#5): succeeds
    assert_equals conn_call($root, qw(postnew 42 subj text:text user b)), 5;
    # FIXME: is this correct? -> TS_ASSERT_EQUALS(server::talk::Topic(root, topicId).firstPostingId().get(), topicId);

    ##  At this point we have four postings authored by a and one authored by b.
    ##  #2 has answer permissions set.

    # - Reply to #1 as b (should fail)
    assert_throws sub{ conn_call($b, qw(postreply 1 reply text:text)) }, 403;

    # - Reply to #2 as b (should succeed due to thread permissions) (#6)
    assert_equals conn_call($b, qw(postreply 2 reply text:text)), 6;

    # - Reply to #1 as b with root permissions (should work, root can do anything) (#7)
    assert_equals conn_call($root, qw(postreply 1 reply text:text user b)), 7;

    # - Reply to #1 as b with implicit+explicit permissions (should fail)
    assert_throws sub{ conn_call($b, qw(postreply 1 reply text:text user b)) }, 403;

    # - Reply to #2 as b with different permissions (should fail)
    assert_throws sub{ conn_call($b, qw(postreply 1 reply text:text user a)) }, 403;

    # - Reply to #1 with empty subject (#8)
    # FIXME: is this correct? -> TS_ASSERT_EQUALS(server::talk::Message(root, postId).subject().get(), "subj");

    # - Message not found
    assert_throws sub{ conn_call($root, qw(postreply 999 reply text:text user b)) }, 404;

    # - No user context
    assert_throws sub{ conn_call($root, qw(postreply 1 reply text:text)) }, 403;

    ##  Edit
    # - Edit #1 as root (should succeed)
    conn_call($root, qw(postedit 1 reply text:text2));

    # - Edit #1 as a (should succeed)
    conn_call($a, qw(postedit 1 reply text:text3));

    # - Edit #1 as b (should fail)
    assert_throws sub{ conn_call($b, qw(postedit 1 reply text:text4)) }, 403;

    # - Message not found
    assert_throws sub{ conn_call($root, qw(postedit 999 reply text:text5)) }, 404;
};

# TestServerTalkTalkPost::testRender: test rendering
test 'talk/50_post/render', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header writeperm all name Foorum));
    conn_call($db, 'hset', 'forum:42:header', 'readperm', '-u:b,all');

    # Connections for three users
    my $root = setup_connect_app($setup, 'talk');
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # Initial postings
    conn_call($a, qw(postnew 42 subj text:text));
    conn_call($a, qw(postnew 42 subj text:text2 readperm all));

    # Render as root
    conn_call($root, qw(renderoption format html));
    assert_equals conn_call($root, qw(postrender 1)), "<p>text</p>\n";

    # Render as user a, as HTML
    conn_call($a, qw(renderoption format html));
    assert_equals conn_call($a, qw(postrender 1)), "<p>text</p>\n";

    # Render as user a, as plain-text with per-operation override
    conn_call($a, qw(renderoption format html));
    assert_equals conn_call($a, qw(postrender 1 format text)), "text";

    # Render as user b, as HTML (permission denied)
    conn_call($b, qw(renderoption format html));
    assert_throws sub{ conn_call($b, qw(postrender 1)) }, 403;

    # Render as user b, as HTML (succeeds due to per-thread permissions)
    assert_equals conn_call($b, qw(postrender 2)), "<p>text2</p>\n";

    # Render non-existant
    assert_throws sub{ conn_call($root, qw(postrender 999)) }, 404;

    # Multi-render as a
    my @r = conn_call_list($a, qw(postmrender 1 2));
    assert_equals scalar(@r), 2;
    assert_equals $r[0], "<p>text</p>\n";
    assert_equals $r[1], "<p>text2</p>\n";

    # Multi-render as b
    @r = conn_call_list($b, qw(postmrender 1 2));
    assert_equals scalar(@r), 2;
    assert !$r[0];                   # inaccessible
    assert_equals $r[1], "<p>text2</p>\n";

    # Multi-render nonexistant as root
    @r = conn_call_list($root, qw(postmrender 1 4 2 3));
    assert_equals scalar(@r), 4;
    assert_equals $r[0], "<p>text</p>\n";
    assert !$r[1];
    assert_equals $r[2], "<p>text2</p>\n";
    assert !$r[3];
};

# TestServerTalkTalkPost::testGetInfo: POSTSTAT
test 'talk/50_post/stat', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header writeperm all name Foorum));
    conn_call($db, 'hset', 'forum:42:header', 'readperm', '-u:b,all');

    # Connections for three users
    my $root = setup_connect_app($setup, 'talk');
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # Initial postings
    conn_call($a, qw(postnew 42 subj text:text));
    conn_call($a, qw(postnew 42 subj text:text2 readperm all));

    # Get information as root
    my %i = conn_call_list($root, qw(poststat 1));
    assert_equals $i{thread}, 1;
    assert_equals $i{parent}, 0;
    assert_equals $i{author}, 'a';
    assert_equals $i{subject}, 'subj';

    # Get information as "a"
    %i = conn_call_list($a, qw(poststat 1));
    assert_equals $i{thread}, 1;
    assert_equals $i{parent}, 0;
    assert_equals $i{author}, 'a';
    assert_equals $i{subject}, 'subj';

    # Get information as "b"
    assert_throws sub{ conn_call_list($b, qw(poststat 1)) }, 403;

    # Get information as "b" for post 2
    %i = conn_call_list($b, qw(poststat 2));
    assert_equals $i{thread}, 2;
    assert_equals $i{parent}, 0;
    assert_equals $i{author}, 'a';
    assert_equals $i{subject}, 'subj';

    # Multi-get information as a
    my @is = conn_call_list($a, qw(postmstat 1 2));
    assert_equals scalar(@is), 2;
    assert $is[0];
    assert $is[1];
    assert_equals {@{$is[0]}}->{thread}, 1;
    assert_equals {@{$is[1]}}->{thread}, 2;

    # Multi-get information as b
    @is = conn_call_list($b, qw(postmstat 1 3 2));
    assert_equals scalar(@is), 3;
    assert !$is[0];
    assert !$is[1];
    assert $is[2];
    assert_equals {@{$is[2]}}->{thread}, 2;

    # Multi-get information as root
    @is = conn_call_list($root, qw(postmstat 1 2));
    assert_equals scalar(@is), 2;
    assert $is[0];
    assert $is[1];
    assert_equals {@{$is[0]}}->{thread}, 1;
    assert_equals {@{$is[1]}}->{thread}, 2;

    # Get information for nonexistant
    assert_throws sub{ conn_call($root, qw(poststat 99)) }, 404;
};

# TestServerTalkTalkPost::testGetNewest: test POSTLSNEW
test 'talk/50_post/newest', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header writeperm all name Foorum));
    conn_call($db, 'hset', 'forum:42:header', 'readperm', '-u:b,all');

    # Initial postings
    my $tc = setup_connect_app($setup, 'talk');
    foreach (1 .. 100) {
        # 1, 3, 5, 7, ...., 199: public
        # 2,4,6,8, ..., 200: non-public
        conn_call($tc, qw(postnew 42 subj text:text user a readperm all));
        conn_call($tc, qw(postnew 42 subj text:text user a));
    }

    # List as root
    my @r = conn_call_list($tc, qw(postlsnew 5));
    assert_equals join(',', @r), '200,199,198,197,196';

    # List as 'b' who sees only the odd ones
    conn_call($tc, qw(user b));
    @r = conn_call_list($tc, qw(postlsnew 5));
    assert_equals join(',', @r), '199,197,195,193,191';
};

# TestServerTalkTalkPost::testGetNewest2: Test POSTLSNEW for a user who cannot see anything.
test 'talk/50_post/newest2', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header name Foorum));
    conn_call($db, 'hset', 'forum:42:header', 'readperm', 'u:a');

    # Initial postings
    my $tc = setup_connect_app($setup, 'talk');
    foreach (1 .. 1000) {
        conn_call($tc, qw(postnew 42 subj text:text user b));
    }

    # List as root
    my @r = conn_call_list($tc, qw(postlsnew 5));
    assert_equals scalar(@r), 5;

    # List as 'a' who can see everything because he can read the forum
    conn_call($tc, qw(user a));
    @r = conn_call_list($tc, qw(postlsnew 5));
    assert_equals scalar(@r), 5;

    # List as 'b' who can see everything because he wrote it
    conn_call($tc, qw(user b));
    @r = conn_call_list($tc, qw(postlsnew 5));
    assert_equals scalar(@r), 5;

    # List as 'c' who cannot see anything
    conn_call($tc, qw(user c));
    @r = conn_call_list($tc, qw(postlsnew 5));
    assert_equals scalar(@r), 0;
};

# TestServerTalkTalkPost::testGetHeader: test POSTGET
test 'talk/50_post/get', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'talk.msgid', '@suf');
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header name Foorum writeperm all));
    conn_call($db, 'hset', 'forum:42:header', 'readperm', '-u:b:all');

    # Connections for three users
    my $root = setup_connect_app($setup, 'talk');
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # A posting and a reply
    assert_equals conn_call($a, qw(postnew 42 subj text:text)), 1;
    assert_equals conn_call($b, qw(postreply 1 reply text:text2)), 2;

    # Tests as root
    assert_equals conn_call($root, qw(postget 1 thread)), 1;
    assert_equals conn_call($root, qw(postget 1 subject)), 'subj';
    assert_equals conn_call($root, qw(postget 1 author)), 'a';
    assert_equals conn_call($root, qw(postget 1 rfcmsgid)), '1.1@suf';

    assert_equals conn_call($root, qw(postget 2 thread)), 1;
    assert_equals conn_call($root, qw(postget 2 subject)), 'reply';
    assert_equals conn_call($root, qw(postget 2 author)), 'b';
    assert_equals conn_call($root, qw(postget 2 rfcmsgid)), '2.2@suf';

    assert_throws sub{ conn_call($root, qw(postget 99 thread)) }, 404;

    # Tests as 'b': can only see post 2
    assert_throws sub{ conn_call($b, qw(postget 1 thread)) }, 403;
    assert_throws sub{ conn_call($b, qw(postget 1 rfcmsgid)) }, 403;

    assert_equals conn_call($b, qw(postget 2 thread)), 1;
    assert_equals conn_call($b, qw(postget 2 subject)), 'reply';
    assert_equals conn_call($b, qw(postget 2 author)), 'b';
    assert_equals conn_call($b, qw(postget 2 rfcmsgid)), '2.2@suf';

    assert_throws sub{ conn_call($b, qw(postget 99 thread)) }, 404;
};

# TestServerTalkTalkPost::testRemove: test POSTRM
test 'talk/50_post/rm', sub {
    my $setup = shift;
    prepare($setup);

    # Set up database
    # - make a forum
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd forum:all 42));
    conn_call($db, qw(hmset forum:42:header name Foorum writeperm all));

    # Connections for three users
    my $root = setup_connect_app($setup, 'talk');
    my $a = setup_connect_app($setup, 'talk');
    my $b = setup_connect_app($setup, 'talk');
    conn_call($a, qw(user a));
    conn_call($b, qw(user b));

    # A posting and a reply
    assert_equals conn_call($a, qw(postnew 42 subj text:text)), 1;
    assert_equals conn_call($b, qw(postreply 1 reply text:text2)), 2;

    # Remove first posting as root
    assert_equals conn_call($root, qw(postrm 1)), 1;
    assert_equals conn_call($db, qw(exists msg:1:header)), 0;
    assert_equals conn_call($db, qw(exists thread:1:header)), 1;
    assert_equals conn_call($db, qw(sismember thread:1:messages 1)), 0;
    assert_equals conn_call($db, qw(sismember thread:1:messages 2)), 1;
    assert_equals conn_call($db, qw(sismember forum:42:messages 1)), 0;
    assert_equals conn_call($db, qw(sismember forum:42:messages 2)), 1;

    # Try to remove second posting as 'a': should fail
    assert_throws sub{ conn_call($a, qw(postrm 2)) }, 403;
    assert_equals conn_call($db, qw(exists msg:2:header)), 1;
    assert_equals conn_call($db, qw(exists thread:1:header)), 1;
    assert_equals conn_call($db, qw(sismember thread:1:messages 1)), 0;
    assert_equals conn_call($db, qw(sismember thread:1:messages 2)), 1;
    assert_equals conn_call($db, qw(sismember forum:42:messages 1)), 0;
    assert_equals conn_call($db, qw(sismember forum:42:messages 2)), 1;

    # Try to remove second posting as 'b' (=owner)
    assert_equals conn_call($b, qw(postrm 2)), 1;
    assert_equals conn_call($db, qw(exists msg:2:header)), 0;
    assert_equals conn_call($db, qw(exists thread:1:header)), 0;
    assert_equals conn_call($db, qw(sismember forum:42:messages 1)), 0;
    assert_equals conn_call($db, qw(sismember forum:42:messages 2)), 0;

    # Remove nonexistant
    assert_equals conn_call($root, qw(postrm 1)), 0;
    assert_equals conn_call($root, qw(postrm 100)), 0;
};

sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
}
