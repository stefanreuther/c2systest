#!/usr/bin/perl -w
#
#  Talk: TalkRender
#
#  Synced with TestServerTalkTalkRender, 20170924
#
use strict;
use c2systest;

# TestServerTalkTalkRender::testIt: simple test
# (the original test interrogates the internal state which we cannot do as a system test;
# we just verify it works.)
test 'talk/50_render', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(renderoption baseurl z format raw));

    assert_equals conn_call($tc, qw(render text:hi format html)), "<p>hi</p>\n";
    assert_equals conn_call($tc, qw(render text:hi)), "text:hi";
};
