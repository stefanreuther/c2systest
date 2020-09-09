#!/usr/bin/perl -w
#
#  Host: HostSchedule
#
#  Synced with TestServerHostHostSchedule, 20170925
#
use strict;
use c2systest;

# TestServerHostHostSchedule::testAddQuery: Test adding and querying schedules.
test 'host/50_schedule/add', sub {
    my $setup = shift;
    prepare($setup);
    assert_equals add_game($setup, 'public', 'preparing'), 1;

    my $hc = setup_connect_app($setup, 'host');

    # Replace-to-create:
    conn_call($hc, qw(scheduleset 1 daily 3));

    # Add
    conn_call($hc, qw(scheduleadd 1 weekly 1));

    # Modify
    conn_call($hc, qw(schedulemod 1 untilturn 10));

    # Verify result
    my @sch = conn_call_list_of_hash($hc, qw(schedulelist 1));
    assert_equals scalar(@sch), 2;

    # Added/modified schedule is first
    assert_equals $sch[0]{type}, 1;
    assert_equals $sch[0]{weekdays}, 1;
    assert_equals $sch[0]{condition}, 1;
    assert_equals $sch[0]{condTurn}, 10;
    assert_equals $sch[0]{hostEarly}, 1;
    assert_equals $sch[0]{hostDelay}, 30;

    # Original schedule is second
    assert_equals $sch[1]{type}, 2;
    assert_equals $sch[1]{interval}, 3;
    assert_equals $sch[1]{condition}, 0;
    assert_equals $sch[1]{hostEarly}, 1;
    assert_equals $sch[1]{hostDelay}, 30;

    # Same daytime
    assert_equals $sch[0]{daytime}, $sch[1]{daytime};
};

# TestServerHostHostSchedule::testAddAll: Test adding schedules with all properties.
test 'host/50_schedule/all', sub {
    my $setup = shift;
    prepare($setup);
    assert_equals add_game($setup, 'public', 'preparing'), 1;

    my $hc = setup_connect_app($setup, 'host');

    # Add
    conn_call($hc, qw(scheduleadd 1 daily 3 noearly delay 15 daytime 400 limit 50));

    # Verify result
    my @sch = conn_call_list_of_hash($hc, qw(schedulelist 1));
    assert_equals scalar(@sch), 1;

    assert_equals $sch[0]{type}, 2;
    assert_equals $sch[0]{interval}, 3;
    assert_equals $sch[0]{hostEarly}, 0;
    assert_equals $sch[0]{hostDelay}, 15;
    assert_equals $sch[0]{daytime}, 400;
    assert_equals $sch[0]{hostLimit}, 50;
};

# TestServerHostHostSchedule::testInit: Test initial schedule state.
#     A newly-created game must report an empty schedule.
test 'host/50_schedule/init', sub {
    my $setup = shift;
    prepare($setup);
    assert_equals add_game($setup, 'public', 'preparing'), 1;

    my $hc = setup_connect_app($setup, 'host');
    assert !conn_call_list($hc, qw(schedulelist 1));
};

# TestServerHostHostSchedule::testDaytime: Test automatic daytime assignment.
#     Setting the same (initial) schedule to multiple games must produce different daytimes.
test 'host/50_schedule/daytime', sub {
    my $setup = shift;
    prepare($setup);

    # 3 games
    assert_equals add_game($setup, 'public', 'preparing'), 1;
    assert_equals add_game($setup, 'public', 'preparing'), 2;
    assert_equals add_game($setup, 'public', 'preparing'), 3;

    # Set the same schedule to all
    my $hc = setup_connect_app($setup, 'host');
    foreach (1 .. 3) {
        conn_call($hc, 'scheduleset', $_, 'daily', 3);
    }

    # Verify all 3 schedules
    my @sch1 = conn_call_list_of_hash($hc, qw(schedulelist 1));
    my @sch2 = conn_call_list_of_hash($hc, qw(schedulelist 2));
    my @sch3 = conn_call_list_of_hash($hc, qw(schedulelist 3));

    assert_equals scalar(@sch1), 1;
    assert_equals scalar(@sch2), 1;
    assert_equals scalar(@sch3), 1;

    assert_differs $sch1[0]{daytime}, $sch2[0]{daytime};
    assert_differs $sch2[0]{daytime}, $sch3[0]{daytime};
    assert_differs $sch3[0]{daytime}, $sch1[0]{daytime};
};

# TestServerHostHostSchedule::testDrop: SCHEDULEDROP.
#     Just a simple functionality test.
test 'host/50_schedule/drop', sub {
    my $setup = shift;
    prepare($setup);
    assert_equals add_game($setup, 'public', 'preparing'), 1;

    my $hc = setup_connect_app($setup, 'host');

    # Add
    conn_call($hc, qw(scheduleadd 1 daily 3));
    conn_call($hc, qw(scheduleadd 1 weekly 1));

    # Remove
    conn_call($hc, qw(scheduledrop 1));

    # Verify result
    my @sch = conn_call_list_of_hash($hc, qw(schedulelist 1));
    assert_equals scalar(@sch), 1;
    assert_equals $sch[0]{type}, 2;

    # Remove another
    conn_call($hc, qw(scheduledrop 1));

    # Verify
    assert !conn_call_list($hc, qw(schedulelist 1));

    # Remove another: this is harmless / no-op
    conn_call($hc, qw(scheduledrop 1));
    conn_call($hc, qw(scheduledrop 1));
};

# TestServerHostHostSchedule::testPreview: SCHEDULESHOW
#     Just a simple functionality test.
test 'host/50_schedule/show', sub {
    my $setup = shift;
    prepare($setup);
    assert_equals add_game($setup, 'public', 'preparing'), 1;

    my $hc = setup_connect_app($setup, 'host');

    # Add
    conn_call($hc, qw(scheduleadd 1 daily 3 untilturn 10));

    # Preview "up to 100"
    my @list = conn_call_list($hc, qw(scheduleshow 1 turnlimit 100));

    # - 11 results: master + turn 1..10
    assert_equals scalar(@list), 11;

    # - Differences between turns must be 3 days
    for (my $i = 1; $i < 10; ++$i) {
        assert_equals $list[$i] + 3*60*24, $list[$i+1];
    }

    # Preview "up to 5"
    @list = conn_call_list($hc, qw(scheduleshow 1 turnlimit 5));
    assert_equals scalar(@list), 5;

    # - Differences between turns must be 3 days
    for (my $i = 1; $i < 3; ++$i) {
        assert_equals $list[$i] + 3*60*24, $list[$i+1];
    }

    # Preview "up to 7 days"
    @list = conn_call_list($hc, 'scheduleshow', 1, 'timelimit', 7*60*24, 'turnlimit', 100);

    # Must return master + 2 turns (+ 1 turn: it stops AFTER exceeding the limit).
    # It still needs a turn limit.
    assert_equals scalar(@list), 4;
    assert_equals $list[1] + 3*60*24, $list[2];

    # Unlimited preview is not permitted
    # - ng: returns empty list (as if turnlimit were 0)
    # - classic: always returns the master time even if turnlimit is 0, so also in this case
    @list = conn_call_list($hc, qw(scheduleshow 1));
    assert @list <= 1;
};


sub prepare {
    my $setup = shift;
    setup_add_host($setup, '--nocron');
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Create 'games'. Required for -classic.
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdirhier games));
}

sub add_game {
    my $setup = shift;
    my $type = shift;
    my $state = shift;
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gamesettype', $gid, $type);
    conn_call($hc, 'gamesetstate', $gid, $state);
    return $gid;
}
