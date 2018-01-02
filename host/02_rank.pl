#!/usr/bin/perl -w
#
#  Host: test for ranking commands (formerly manual tests)
#
use strict;
use c2systest;

# The game Id to use
my $g = 200000000;

##
##  Basic ranking test [ex planetscentral/host/test/t_rank.con]
##
##  Default 60 turn game
##  No ranks declared: everyone gets first place
##  -> everyone gets 2000 points
##     Bug #345: it's only 2000*(59/60) = 1967 points
##
test 'host/02_rank/basic', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    for my $s (1 .. 11) {
        my $p = 600+$s;
        assert_equals(conn_call($dbc, "hget", "user:$p:profile", "rankpoints"), 1967);
    }
};

##
##  Basic ranking test: short game [ex planetscentral/host/test/t_rank_short.con]
##
##  Default game, shortened to 40 turns
##  No ranks declared: everyone gets first place
##  -> everyone gets 1600 points (=2000 * 40/50 Turn_Factor)
##     Bug #345: only 1560
##
test 'host/02_rank/short', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($dbc, "hset", "game:$g:settings", "turn", 40);
    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    for my $s (1 .. 11) {
        my $p = 600+$s;
        assert_equals(conn_call($dbc, "hget", "user:$p:profile", "rankpoints"), 1560);
    }
};

##
##  Basic ranking test: scores [ex planetscentral/host/test/t_rank_order.con]
##
##  Default 60 turn game
##  Players have scores
##  -> point distribution according to table (2000, 1400, ..., 100)
##
test 'host/02_rank/order', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($dbc, "hset", "game:$g:turn:60:scores", "score", "\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04\0\0\0\x05\0\0\0\x06\0\0\0\x07\0\0\0\x08\0\0\0\x09\0\0\0\x0a\0\0\0\x0b\0\0\0");
    conn_call($dbc, "hset", "game:$g:settings", "endScoreName", "score");
    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    assert_equals(conn_call($dbc, "hget", "user:601:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:602:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:603:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:604:profile", "rankpoints"), 197);
    assert_equals(conn_call($dbc, "hget", "user:605:profile", "rankpoints"), 295);
    assert_equals(conn_call($dbc, "hget", "user:606:profile", "rankpoints"), 393);
    assert_equals(conn_call($dbc, "hget", "user:607:profile", "rankpoints"), 589);
    assert_equals(conn_call($dbc, "hget", "user:608:profile", "rankpoints"), 786);
    assert_equals(conn_call($dbc, "hget", "user:609:profile", "rankpoints"), 982);
    assert_equals(conn_call($dbc, "hget", "user:610:profile", "rankpoints"), 1375);
    assert_equals(conn_call($dbc, "hget", "user:611:profile", "rankpoints"), 1964);
};

##
##  Basic ranking test: replacement [ex planetscentral/host/test/t_rank_repl.con]
##
##  Default 60 turn game
##  Player 3 starts as 612, then replaced by 603
##  Players have scores
##  -> point distribution according to table. Everyone gets usual points, 603 and 612 share.
##
test 'host/02_rank/repl', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($dbc, "hset", "game:$g:turn:60:scores", "score", "\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04\0\0\0\x05\0\0\0\x06\0\0\0\x07\0\0\0\x08\0\0\0\x09\0\0\0\x0a\0\0\0\x0b\0\0\0");
    conn_call($dbc, "hset", "game:$g:settings", "endScoreName", "score");
    foreach my $t (1 .. 20) {
        conn_call($dbc, "hset", "game:$g:turn:$t:player", 3, 612);
    }
    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    assert_equals(conn_call($dbc, "hget", "user:601:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:602:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:603:profile", "rankpoints"), 67);
    assert_equals(conn_call($dbc, "hget", "user:604:profile", "rankpoints"), 197);
    assert_equals(conn_call($dbc, "hget", "user:605:profile", "rankpoints"), 295);
    assert_equals(conn_call($dbc, "hget", "user:606:profile", "rankpoints"), 393);
    assert_equals(conn_call($dbc, "hget", "user:607:profile", "rankpoints"), 589);
    assert_equals(conn_call($dbc, "hget", "user:608:profile", "rankpoints"), 786);
    assert_equals(conn_call($dbc, "hget", "user:609:profile", "rankpoints"), 982);
    assert_equals(conn_call($dbc, "hget", "user:610:profile", "rankpoints"), 1375);
    assert_equals(conn_call($dbc, "hget", "user:611:profile", "rankpoints"), 1964);
    assert_equals(conn_call($dbc, "hget", "user:612:profile", "rankpoints"), 32);
};

##
##  Basic ranking test, differing input ranks [ex planetscentral/host/test/t_rank_diff.con]
##
##  Default 60 turn game
##  Players have scores
##  Player 5 already has rank 10
##  -> point distribution according to table; ranks above get more points,
##     5 gets fewer points, below get regular points
##
test 'host/02_rank/diff', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($dbc, "hset", "game:$g:turn:60:scores", "score", "\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04\0\0\0\x05\0\0\0\x06\0\0\0\x07\0\0\0\x08\0\0\0\x09\0\0\0\x0a\0\0\0\x0b\0\0\0");
    conn_call($dbc, "hset", "game:$g:settings", "endScoreName", "score");
    conn_call($dbc, "hmset", "user:605:profile", "rank", 9, "rankpoints", 6666, "turnreliability", 90000, "turnsplayed", 222, "turnsmissed", 2);
    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    assert_equals(conn_call($dbc, "hget", "user:601:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:602:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:603:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:604:profile", "rankpoints"), 197);
    assert_equals(conn_call($dbc, "hget", "user:605:profile", "rankpoints"), 6890);  # +224
    assert_equals(conn_call($dbc, "hget", "user:606:profile", "rankpoints"), 423);
    assert_equals(conn_call($dbc, "hget", "user:607:profile", "rankpoints"), 635);
    assert_equals(conn_call($dbc, "hget", "user:608:profile", "rankpoints"), 845);
    assert_equals(conn_call($dbc, "hget", "user:609:profile", "rankpoints"), 1056);
    assert_equals(conn_call($dbc, "hget", "user:610:profile", "rankpoints"), 1477);
    assert_equals(conn_call($dbc, "hget", "user:611:profile", "rankpoints"), 2109);
};

##
##  Basic ranking test
##
##  Default 60 turn game
##  Player 3 joins late (turn 21)
##  Players have scores
##  -> point distribution according to table. High ranks get less points
##     (it was easier when player 3 was not playing)
##
test 'host/02_rank/late', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($dbc, "hset", "game:$g:turn:60:scores", "score", "\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04\0\0\0\x05\0\0\0\x06\0\0\0\x07\0\0\0\x08\0\0\0\x09\0\0\0\x0a\0\0\0\x0b\0\0\0");
    conn_call($dbc, "hset", "game:$g:settings", "endScoreName", "score");
    foreach my $t (1 .. 20) {
        conn_call($dbc, "hset", "game:$g:turn:$t:info", "turnstatus", "\x01\x00\x01\x00\xff\xff\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00");
        conn_call($dbc, "hdel", "game:$g:turn:$t:player", 3);
    }
    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    assert_equals(conn_call($dbc, "hget", "user:601:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:602:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:603:profile", "rankpoints"), 67);
    assert_equals(conn_call($dbc, "hget", "user:604:profile", "rankpoints"), 196);
    assert_equals(conn_call($dbc, "hget", "user:605:profile", "rankpoints"), 294);
    assert_equals(conn_call($dbc, "hget", "user:606:profile", "rankpoints"), 392);
    assert_equals(conn_call($dbc, "hget", "user:607:profile", "rankpoints"), 588);
    assert_equals(conn_call($dbc, "hget", "user:608:profile", "rankpoints"), 784);
    assert_equals(conn_call($dbc, "hget", "user:609:profile", "rankpoints"), 980);
    assert_equals(conn_call($dbc, "hget", "user:610:profile", "rankpoints"), 1371);
    assert_equals(conn_call($dbc, "hget", "user:611:profile", "rankpoints"), 1959);
};

##
##  Basic ranking test: undo
##
##  This is the same as /order, but we claim in the database to have already given 1000 points to everyone.
##  The net result should be the same as for /order.
##
test 'host/02_rank/undo', sub {
    my $setup = shift;
    my ($hc, $dbc) = prepare($setup);

    lib_create_players($dbc);
    lib_create_game($dbc, $g);

    conn_call($dbc, "hset", "game:$g:turn:60:scores", "score", "\x01\0\0\0\x02\0\0\0\x03\0\0\0\x04\0\0\0\x05\0\0\0\x06\0\0\0\x07\0\0\0\x08\0\0\0\x09\0\0\0\x0a\0\0\0\x0b\0\0\0");
    conn_call($dbc, "hset", "game:$g:settings", "endScoreName", "score");
    conn_call($dbc, "hset", "game:$g:settings", "rankTurn", 20);
    foreach my $s (1 .. 11) {
        my $p = 600+$s;
        conn_call($dbc, "hset", "game:$g:rankpoints", $p, 1000);
        conn_call($dbc, "hset", "user:$p:profile", "rankpoints", 1000);
    }
    conn_call($hc, "gamesetstate", $g, "finished");

    # Verify
    assert_equals(conn_call($dbc, "hget", "user:601:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:602:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:603:profile", "rankpoints"), 98);
    assert_equals(conn_call($dbc, "hget", "user:604:profile", "rankpoints"), 197);
    assert_equals(conn_call($dbc, "hget", "user:605:profile", "rankpoints"), 295);
    assert_equals(conn_call($dbc, "hget", "user:606:profile", "rankpoints"), 393);
    assert_equals(conn_call($dbc, "hget", "user:607:profile", "rankpoints"), 589);
    assert_equals(conn_call($dbc, "hget", "user:608:profile", "rankpoints"), 786);
    assert_equals(conn_call($dbc, "hget", "user:609:profile", "rankpoints"), 982);
    assert_equals(conn_call($dbc, "hget", "user:610:profile", "rankpoints"), 1375);
    assert_equals(conn_call($dbc, "hget", "user:611:profile", "rankpoints"), 1964);
};


##
##  Library routines for test game [ex planetscentral/host/test/libgame.con]
##

# Create dummy players.
sub lib_create_players {
    my $dbc = shift;
    foreach my $p (601 .. 612) {
        conn_call($dbc, "set",  "user:$p:name", "test_user_$p");
        conn_call($dbc, "hset", "user:$p:profile", "realname", "Test User $p");
        conn_call($dbc, "hset", "user:$p:profile", "screenname", "Test User $p");
        conn_call($dbc, "hmset", "user:$p:profile", "turnreliability", 90000, "turnsplayed", 100, "turnsmissed", 5);
    }
}

# Create the game
sub lib_create_game {
    my $dbc = shift;
    my $g = shift;
    conn_call($dbc, "set", "game:$g:name", "Test Game");
    conn_call($dbc, "set", "game:$g:state", "running");
    conn_call($dbc, "set", "game:$g:type", "public");

    # Join players
    foreach my $s (1 .. 11) {
        my $p = $s+600;
        conn_call($dbc, "lpush", "game:$g:player:$s:users", $p);
        conn_call($dbc, "hmset", "game:$g:player:$s:status", "slot", 1, "turn", 1);
        conn_call($dbc, "hset",  "game:$g:users", $p, 1);
        conn_call($dbc, "hset",  "user:$p:games", $g, 1);
        conn_call($dbc, "set",   "game:$g:dir", "/tmp/zzz");
    }
    conn_call($dbc, "hmset", "game:$g:settings", "lastHostTime", 999999999, "host", "phost-current", "turn", 60);
    conn_call($dbc, "hmset", "game:$g:cache", "difficulty", 100);

    # Turn and score history
    foreach my $t (1 .. 60) {
        conn_call($dbc, "hset", "game:$g:turn:$t:info", "turnstatus", "\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00\x01\x00");
        foreach my $s (1 .. 11) {
            conn_call($dbc, "hset", "game:$g:turn:$t:player", $s, $s+600);
        }
    }

    # Indexes
    foreach (qw(game:all game:state:running game:pubstate:running)) {
        conn_call($dbc, 'sadd', $_, $g);
    }
}



sub prepare {
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $db = setup_add_db($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);
    my $dbc = service_connect($db);
    ($hc, $dbc);
}
