#!/usr/bin/perl -w
#
#  Host: GameRootItem
#
#  Synced with TestServerHostFileGameRootItem, 20180614
#
use strict;
use c2systest;
use c2service;

my $TURN_NUMBER = 30;

sub conn_call_multi {
    my $conn = shift;
    foreach (@_) {
        conn_call($conn, split /\s+/, $_);
    }
}

# TestServerHostFileGameRootItem::testGame: test file structure
test 'host/50_gamerootitem', sub {
    my $setup = shift;
    setup_add_host($setup, '--nocron');
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Create users
    # Deliberately not initialize user:id.
    # This means user Ids start at 1, which uncovered a bug in loadPrimaryPlayers.
    my %u;
    foreach (qw(a b c d e f)) {
        $u{$_} = c2service::setup_add_user($setup, $_);
    }

    # Create game
    my $dbc = setup_connect_app($setup, 'db');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $gameId = 42;
    my $gameDir = sprintf("games/%04d", $gameId);
    conn_call_multi($dbc,
                    "set game:$gameId:dir $gameDir",
                    "set game:$gameId:name Name",
                    "set game:$gameId:state running",
                    "set game:$gameId:type public",
                    "sadd game:all $gameId",
                    "sadd game:pubstate:running $gameId",
                    "sadd game:state:running $gameId",
                    "hset game:$gameId:settings turn $TURN_NUMBER",
                    map {"hmset game:$gameId:player:$_:status slot 1 turn 0"} 1..11);

    conn_call_multi($hfc,
                    "mkdirhier $gameDir",
                    "mkdirhier $gameDir/in/new",
                    "mkdirhier $gameDir/out/all",
                    "mkdirhier $gameDir/data",
                    "mkdirhier $gameDir/backup",
                    map {"mkdirhier $gameDir/out/$_"} 1..11);

    create_game_history($dbc, $hfc, $gameDir, $gameId);
    create_player_history($dbc, $hfc, $gameDir, $gameId, \%u);

    ##
    ##  Test
    ##
    my $hc = setup_connect_app($setup, 'host');

    # Check tree syntax and connectivity for each user
    # Player a sees 30 turns for player 1 and 4.
    conn_call($hc, 'user', $u{a});
    assert_equals check_tree($hc, "game/42", 42, 0), 218;

    #     // FIXME -> Player b is sees 20 turns. <- fails because not on game. Should they?
    #     // TS_ASSERT_EQUALS(checkTree(root, "42", "b"), ...);

    # Player c sees 10 turns (and 30 results).
    conn_call($hc, 'user', $u{c});
    assert_equals check_tree($hc, "game/42", 42, 0), 118;

    # Player d sees 30 turns for one player. Same thing for e who replaces them.
    conn_call($hc, 'user', $u{d});
    assert_equals check_tree($hc, "game/42", 42, 0), 136;
    conn_call($hc, 'user', $u{e});
    assert_equals check_tree($hc, "game/42", 42, 0), 136;

    # Same thing for f.
    conn_call($hc, 'user', $u{f});
    assert_equals check_tree($hc, "game/42", 42, 0), 136;

    # Admin sees everything:
    conn_call($hc, 'user', '');
    assert_equals check_tree($hc, "game/42", 42, 0), 644;

    # Check content of some files.
    conn_call($hc, 'user', $u{f});
    assert_equals conn_call($hc, 'get', 'game/42/history/25/race.nm'), 'pre-spec-26';
    assert_equals conn_call($hc, 'get', 'game/42/history/25/4/player4.rst'), "pre-26-4";
    assert_equals conn_call($hc, 'get', 'game/42/history/25/4/player4.trn'), "turn-26-4";
    assert_equals conn_call($hc, 'get', 'game/42/history/25/4/player4.trn'), "turn-26-4";

    conn_call($hc, 'user', $u{a});
    assert_equals conn_call($hc, 'get', 'game/42/xyplan.dat'), "current-spec";

    conn_call($hc, 'user', $u{c});
    assert_equals conn_call($hc, 'get', 'game/42/history/12/2/player2.rst'), "pre-13-2";
    assert_equals conn_call($hc, 'get', 'game/42/history/22/2/player2.rst'), "pre-23-2";
    assert_equals conn_call($hc, 'get', 'game/42/history/22/2/player2.trn'), "turn-23-2";
    assert_equals conn_call($hc, 'get', 'game/42/2/player2.trn'), "current-turn-2";
    assert_equals conn_call($hc, 'get', 'game/42/2/player2.rst'), "current-rst-2";

    # Check nonexistance/inaccessibility of some files
    conn_call($hc, 'user', $u{f});
    assert_throws sub{ conn_call($hc, 'get', 'game/77/xyplan.dat') }, 404;

    conn_call($hc, 'user', 998);
    assert_throws sub{ conn_call($hc, 'get', 'game/42/history/25/race.nm') }, 403;

    conn_call($hc, 'user', $u{b});
    assert_throws sub{ conn_call($hc, 'get', 'game/42/history/25/4/player4.rst') }, qr{403|404};

    conn_call($hc, 'user', $u{c});
    assert_throws sub{ conn_call($hc, 'get', 'game/42/history/12/2/player2.trn') }, 404;

    conn_call($hc, 'user', '');
    assert_throws sub{ conn_call($hc, 'get', 'game/42/history/50/race.nm') }, 404;
    assert_throws sub{ conn_call($hc, 'get', 'game/150/race.nm') }, 404;
    assert_throws sub{ conn_call($hc, 'get', 'game/025/race.nm') }, 404;
};


# Populate the game history.
# Creates all files and historical records.
sub create_game_history {
    my ($dbc, $hfc, $gameDir, $gameId) = @_;

    foreach my $turn (1 .. $TURN_NUMBER) {
        # Files
        foreach (qw(pre post trn)) {
            conn_call($hfc, 'mkdir', sprintf("%s/backup/%s-%03d", $gameDir, $_, $turn));
        }
        foreach my $slot (1 .. 5) {
            if ($turn > 1) {
                conn_call($hfc, 'put', sprintf("%s/backup/trn-%03d/player%d.trn", $gameDir, $turn, $slot), sprintf("turn-%d-%d", $turn, $slot));
                conn_call($hfc, 'put', sprintf("%s/backup/pre-%03d/player%d.rst", $gameDir, $turn, $slot), sprintf("pre-%d-%d", $turn, $slot));
            }
            conn_call($hfc, 'put', sprintf("%s/backup/post-%03d/player%d.rst", $gameDir, $turn, $slot), sprintf("post-%d-%d", $turn, $slot));
        }
        if ($turn > 1) {
            conn_call($hfc, 'put', sprintf("%s/backup/pre-%03d/race.nm", $gameDir, $turn), sprintf("pre-spec-%d", $turn));
        }
        conn_call($hfc, 'put', sprintf("%s/backup/post-%03d/race.nm", $gameDir, $turn), sprintf("post-spec-%d", $turn));

        # Database
        conn_call($dbc, 'hset', "game:$gameId:turn:$turn:scores", 'timscore', "\1" x 22);
        conn_call($dbc, 'hmset', "game:$gameId:turn:$turn:info",
                  'time', 1000+$turn,
                  'timestamp', sprintf("01-01-200019:20:%02d", $turn),
                  'turnstatus', "\1\0" x 11);
        if ($turn >= 10) {
            # Pretend that recordings start at turn 10
            conn_call_multi($dbc, "sadd game:$gameId:turn:$turn:files:all race.nm",
                            map {"sadd game:$gameId:turn:$turn:files:$_ player$_.rst"} 1..5);
        }
    }

    # Current turn
    conn_call($hfc, 'put', sprintf("%s/out/all/xyplan.dat", $gameDir), "current-spec");
    conn_call($hfc, 'put', sprintf("%s/out/all/playerfiles.zip", $gameDir), "current-zip");
    foreach my $slot (1 .. 5) {
        conn_call($hfc, 'put', sprintf("%s/in/player%d.trn", $gameDir, $slot), sprintf("current-turn-%d", $slot));
        conn_call($hfc, 'put', sprintf("%s/out/%d/player%d.rst", $gameDir, $slot, $slot), sprintf("current-rst-%d", $slot));
        conn_call($dbc, 'hset', "game:$gameId:player:$slot:status", 'turn', 1);
    }
}

# Populate player history.
# Adds players to the game and fills their historical records.
sub create_player_history {
    my ($dbc, $hfc, $gameDir, $gameId, $pu) = @_;

    # "a" plays Fed for whole game
    foreach my $turn (1 .. $TURN_NUMBER) {
        conn_call($dbc, 'hset', "game:$gameId:turn:$turn:player", 1, $pu->{a});
    }
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 1, $pu->{a});

    # "b" plays Lizard and is replaced by "c" in turn 20
    foreach my $turn (1 .. $TURN_NUMBER) {
        conn_call($dbc, 'hset', "game:$gameId:turn:$turn:player", 2, $turn < 20 ? $pu->{b} : $pu->{c});
    }
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 2, $pu->{b});
    pop_player_slot($dbc, $hfc, $gameDir, $gameId, 2);
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 2, $pu->{c});

    # "d" plays Bird for whole game and has a replacement "e"
    foreach my $turn (1 .. $TURN_NUMBER) {
        conn_call($dbc, 'hset', "game:$gameId:turn:$turn:player", 3, $pu->{d});
    }
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 3, $pu->{d});
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 3, $pu->{e});

    # "f" plays Klingon, and has replacement "a"
    foreach my $turn (1 .. $TURN_NUMBER) {
        conn_call($dbc, 'hset', "game:$gameId:turn:$turn:player", 4, $pu->{f});
    }
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 4, $pu->{f});
    push_player_slot($dbc, $hfc, $gameDir, $gameId, 4, $pu->{a});
}

# Check file tree beneath an item for consistency.
sub check_tree {
    my ($hc, $path, $name, $level) = @_;

    # Fetch status
    my %item = conn_call_list($hc, 'stat', $path);
    assert_differs $item{name}, '';
    assert_equals $item{name}, $name;
    assert $level < 10;

    # Verify path info
    my @path = conn_call_list($hc, 'pstat', $path);
    assert_differs scalar(@path), 0;
    my %pathItem = @{$path[-1]};
    foreach (sort(keys %pathItem), sort(keys %item)) {
        assert_equals $pathItem{$_}, $item{$_};
    }

    # Verify content
    my $result = 0;
    if ($item{type} eq 'dir') {
        # Must be listable but not readable
        assert_throws sub{ conn_call($hc, 'get', $path) }, 403;
        my @list = conn_call_list($hc, 'ls', $path);
        ++$result;
        assert_equals @list % 2, 0;
        for (my $i = 0; $i < @list; $i += 2) {
            # Verify subtree
            assert $list[$i+1];
            my %e = @{$list[$i+1]};
            assert_equals $e{name}, $list[$i];
            $result += check_tree($hc, "$path/$e{name}", $e{name}, $level+1);
        }
    } elsif ($item{type} eq 'file') {
        # Must be readable but not listable
        assert_differs conn_call($hc, 'get', $path), '';
        assert_throws sub{ conn_call($hc, 'ls', $path) }, 405;
        ++$result;
    } else {
        assert_failure "Wrong file type $item{type}";
    }
    return $result;
}

sub push_player_slot {
    my ($dbc, $hfc, $gameDir, $gameId, $slot, $u) = @_;
    conn_call_multi($dbc, "rpush game:$gameId:player:$slot:users $u",
                    "hincrby game:$gameId:users $u 1",
                    "hincrby game:$u:games $gameId 1");

    conn_call_multi($hfc,
                    "setperm $gameDir/in/new $u w",
                    "setperm $gameDir/out/all $u rl",
                    "setperm $gameDir/out/$slot $u rl");
}

sub pop_player_slot {
    my ($dbc, $hfc, $gameDir, $gameId, $slot) = @_;
    my $u = conn_call($dbc, 'rpop', "game:$gameId:player:$slot:users");

    conn_call_multi($dbc,
                    "hincrby game:$gameId:users $u -1",
                    "hincrby game:$u:games $gameId -1");

    conn_call_multi($hfc,
                    "setperm $gameDir/in/new $u 0",
                    "setperm $gameDir/out/all $u 0",
                    "setperm $gameDir/out/$slot $u 0");
}
