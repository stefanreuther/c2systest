#!/usr/bin/perl -w
#
#  Talk: TalkSyntax
#
#  Synced with TestServerTalkTalkSyntax, 20170924
#
use strict;
use c2systest;


# TestServerTalkTalkSyntax::testIt
test 'talk/50_syntax', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);

    my $keyword_table_file = setup_get_tmpfile_name($setup, 'kt.txt');
    setup_add_service_config($setup, 'talk.syntaxdb', $keyword_table_file);
    file_put($keyword_table_file, 'k = v');

    setup_start_wait($setup);

    # Single get
    my $tc = setup_connect_app($setup, 'talk');
    assert_equals conn_call($tc, qw(syntaxget k)), 'v';
    assert_equals conn_call($tc, qw(syntaxget K)), 'v';
    assert_throws sub{ conn_call($tc, qw(syntaxget x)) }, 404;

    # Multi get
    my @r = conn_call_list($tc, qw(syntaxmget j k l));
    assert_equals scalar(@r), 3;
    assert !$r[0];
    assert_equals $r[1], 'v';
    assert !$r[2];
};
