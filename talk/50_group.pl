#!/usr/bin/perl -w
#
#  Talk: TalkGroup
#
#  Synced with TestServerTalkTalkGroup, 20170923
#  Fails with c2talk-classic.
#
use strict;
use c2systest;

# TestServerTalkTalkGroup::testIt: simple tests
test 'talk/50_group', sub {
    my $setup = shift;
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create two sessions
    my $root_tc = setup_connect_app($setup, 'talk');
    my $user_tc = setup_connect_app($setup, 'talk');
    conn_call($user_tc, qw(user a));

    # Create some groups
    conn_call($root_tc, 'groupadd', 'root', name => 'All', description => 'text:All forums', key => '000-root');
    conn_call($root_tc, 'groupadd', 'sub',  name => 'Subgroup', description => 'text:Some more forums', parent => 'root');
    conn_call($root_tc, 'groupadd', 'unlisted', name => 'Unlisted forums', description => 'text:Secret', unlisted => 1);

    # User creating a group - fails, users cannot do that
    assert_throws sub{ conn_call($user_tc, 'groupadd', 'root2', name => 'My', description => 'text:My forums') }, 403;

    # Add some forums [just for testing]
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(sadd group:root:forums 1));
    conn_call($dbc, qw(sadd group:sub:forums 2));
    conn_call($dbc, qw(sadd group:unlisted:forums 3));

    # Configure
    # - Adding root fails because it already exists
    assert_throws sub{ conn_call($root_tc, 'groupadd', 'root', name => 'Root') }, 409;

    # - Configuring root works
    conn_call($root_tc, 'groupset', 'root', name => 'Root');

    # - ...but not as user
    assert_throws sub{ conn_call($user_tc, 'groupset', 'root', name => 'Root') }, 403;

    # - Configuring other fails because it does not exist
    assert_throws sub{ conn_call($root_tc, 'groupset', 'other', name => 'Root') }, 404;

    # Query info
    assert_equals conn_call($root_tc, qw(groupget root name)), 'Root';
    assert_equals conn_call($root_tc, qw(groupget root key)), '000-root';
    assert_equals conn_call($user_tc, qw(groupget root name)), 'Root';
    assert_equals conn_call($root_tc, qw(groupget unlisted description)), 'text:Secret';

    # Query content
    # - Root queries root group
    my %c = conn_call_list($root_tc, qw(groupls root));
    assert_equals list($c{groups}), 'sub';
    assert_equals list($c{forums}), '1';

    # - User queries root group
    %c = conn_call_list($user_tc, qw(groupls root));
    assert_equals list($c{groups}), 'sub';
    assert_equals list($c{forums}), '1';

    # - Root queries unlisted group - root can do that
    %c = conn_call_list($root_tc, qw(groupls unlisted));
    assert_equals list($c{groups}), '';
    assert_equals list($c{forums}), '3';

    # - User queries unlisted group
    %c = conn_call_list($user_tc, qw(groupls unlisted));
    assert_equals list($c{groups}), '';
    assert_equals list($c{forums}), '';

    # Get description; this renders, and also provides unlisted group headers.
    conn_call($user_tc, qw(renderoption format html));

    %c = conn_call_list($user_tc, qw(groupstat root));
    assert_equals $c{name}, 'Root';
    assert_equals $c{description}, "<p>All forums</p>\n";
    assert_equals $c{parent}, '';       # undefined with classic
    assert_equals $c{unlisted}, 0;

    %c = conn_call_list($user_tc, qw(groupstat unlisted));
    assert_equals $c{name}, 'Unlisted forums';
    assert_equals $c{description}, "<p>Secret</p>\n";
    assert_equals $c{parent}, '';
    assert_equals $c{unlisted}, 1;

    # Same thing, multiple in one call
    my @cs = conn_call_list($user_tc, qw(groupmstat root sub unlisted));
    assert_equals scalar(@cs), 3;
    assert $cs[0];
    assert $cs[1];
    assert $cs[2];

    %c = @{$cs[0]};
    assert_equals $c{name}, 'Root';

    %c = @{$cs[1]};
    assert_equals $c{name}, 'Subgroup';

    %c = @{$cs[2]};
    assert_equals $c{name}, 'Unlisted forums';
};

sub list {
    my $p = shift;
    join(',', @$p);
}
