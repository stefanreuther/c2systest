#!/usr/bin/perl -w
#
#  Talk: CommandHandler
#
#  Synced with TestServerTalkCommandHandler, 20170923
#
use strict;
use c2systest;

# TestServerTalkCommandHandler::testIt: Simple test
test 'talk/50_ch', sub {
    # Setup
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);

    my $keyword_table_file = setup_get_tmpfile_name($setup, 'kt.txt');
    setup_add_service_config($setup, 'talk.syntaxdb', $keyword_table_file);
    file_put($keyword_table_file, 'KEYWORD = Info');

    setup_start_wait($setup);
    my $tc = setup_connect_app($setup, 'talk');

    # Basic commands
    assert_equals conn_call($tc, 'PING'), 'PONG';
    assert_num_greater length(conn_call($tc, 'HELP')), 20;

    # Syntax
    assert_equals conn_call($tc, qw(SYNTAXGET KEYWORD)), 'Info';
    assert_equals conn_call($tc, qw(syntaxget KEYWORD)), 'Info';

    # Render
    assert_equals conn_call($tc, qw(RENDER text:x FORMAT html)), "<p>x</p>\n";
    assert_equals conn_call($tc, qw(render text:x format html)), "<p>x</p>\n";

    # Group
    conn_call($tc, qw(GROUPADD g name gn));
    assert_equals conn_call($tc, qw(GROUPGET g name)), 'gn';

    # Forum
    assert_equals conn_call($tc, qw(FORUMADD name f readperm all)), 1;

    # Post
    assert_equals conn_call($tc, qw(POSTNEW 1 title text USER a)), 1;

    # Thread
    my %s = conn_call_list($tc, qw(THREADSTAT 1));
    assert_equals $s{subject}, 'title';

    # User
    my @a = conn_call_list($tc, qw(USERLSPOSTED a));
    assert_equals scalar(@a), 1;
    assert_equals $a[0], 1;

    # Change user context. Required for Folder/PM.
    conn_call($tc, qw(user 1009));

    # Folder
    assert_equals conn_call($tc, qw(FOLDERNEW fn)), 100;

    # PM
    assert_equals conn_call($tc, qw(PMNEW u:b pmsubj pmtext)), 1;

    # NNTP
    %s = conn_call_list($tc, qw(NNTPPOSTHEAD 1));
    assert_equals $s{Subject}, 'title';

    # Some errors
    assert_throws sub{ conn_call($tc, qw(NNTPWHATEVER)) }, 400;
    assert_throws sub{ conn_call($tc, qw(huh?)) }, 400;
    assert_throws sub{ conn_call($tc) };                           # Does not come with a code!
};
