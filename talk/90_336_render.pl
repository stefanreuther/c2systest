#!/usr/bin/perl -w
#
#  Talk: bug 336, rendering inconsistency
#
use strict;
use c2systest;

# Same as TestServerTalkTalkPM::testRender.
test 'talk/90_336_render', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Configure db - just what is needed
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(sadd user:1001:pm:folder:1:messages 10));
    conn_call($dbc, qw(set user:1001:name streu));
    conn_call($dbc, qw(set user:1003:name b));
    conn_call($dbc, qw(hset pm:10:header author 1003));
    conn_call($dbc, qw(set pm:10:text), "forum:let's test this");

    # Configure session
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, qw(user 1001));
    conn_call($tc, qw(renderoption format quote:forum));

    # Test it
    my $EXPECT = "[quote=b]\nlet's test this[/quote]";

    # - render
    assert_equals conn_call($tc, qw(pmrender 1 10)), $EXPECT;

    # - mrender
    my @r = conn_call_list($tc, qw(pmmrender 1 10));
    assert_equals scalar(@r), 1;
    assert_equals $r[0], $EXPECT;
};

