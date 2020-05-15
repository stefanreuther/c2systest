#!/usr/bin/perl -w
#
#  Host: HostGame
#
#  Synced with TestServerHostHostGame, 20170925
#
use strict;
use c2systest;
use c2service;

# TestServerHostHostGame::testCloneGameErrorLocked: not testable in system test
# TestServerHostHostGame::testGetPermissions: already on 90_350_checkperm

# TestServerHostHostGame::testNewGame: NEWGAME.
#    Tests just basic operation.
#    Actual game creation is tested separately.
#    A complete test is in host/02_newgame.
test 'host/50_game/new', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');

    # Creating two games must create distinct Ids
    my $a = conn_call($hc, qw(newgame));
    my $b = conn_call($hc, qw(newgame));
    assert_equals $a, 1;
    assert_equals $b, 2;

    # Name and type
    assert_equals conn_call($hc, qw(gamegetname 1)), 'New Game';
    assert_equals conn_call($hc, qw(gamegetstate 1)), 'preparing';
    assert_equals conn_call($hc, qw(gamegettype 1)), 'private';
    assert_equals conn_call($hc, qw(gamegetdir 1)), 'games/0001';

    # Stats
    my %stats = conn_call_list($hc, qw(gametotals));
    assert_equals $stats{joining}, 0;
    assert_equals $stats{running}, 0;
    assert_equals $stats{finished}, 0;
};

# TestServerHostHostGame::testCloneGame: CLONEGAME, standard case.
#    Tests just basic operation.
#    Actual game creation is tested separately.
test 'host/50_game/clone/standard', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');

    # Create a game and clone it
    assert_equals conn_call($hc, qw(newgame)), 1;
    assert_equals conn_call($hc, qw(clonegame 1)), 2;

    # Verify
    assert_equals conn_call($hc, qw(gamegetname 2)), 'New Game 1';
    assert_equals conn_call($hc, qw(gamegetstate 2)), 'joining';
    assert_equals conn_call($hc, qw(gamegettype 2)), 'private';
};

# TestServerHostHostGame::testCloneGameStatus: CLONEGAME, operation with target state.
test 'host/50_game/clone/status', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');

    # Create a game and clone it
    assert_equals conn_call($hc, qw(newgame)), 1;
    assert_equals conn_call($hc, qw(clonegame 1 preparing)), 2;

    # Verify
    assert_equals conn_call($hc, qw(gamegetname 2)), 'New Game 1';
    assert_equals conn_call($hc, qw(gamegetstate 2)), 'preparing';
    assert_equals conn_call($hc, qw(gamegettype 2)), 'private';
};

# TestServerHostHostGame::testCloneGameErrorUser: CLONEGAME, error case.
#    Users cannot clone games.
test 'host/50_game/clone/error/user', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');

    # Create a game
    assert_equals conn_call($hc, qw(newgame)), 1;

    # Set user context
    conn_call($hc, qw(user u));

    # Clone game. Must fail (admin-only operation).
    assert_throws sub{ conn_call($hc, qw(clonegame 1)) }, 403;
};

# TestServerHostHostGame::testCloneGameId: CLONEGAME, error case.
#    Cloning fails if the source game does not exist.
test 'host/50_game/clone/error/id', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');

    # The first game will receive the Id 1. This clone must fail (and not create game 1 and copy it onto itself).
    assert_throws sub{ conn_call($hc, qw(clonegame 1)) }, 404;

    # Clone game with invented Id. Must fail.
    assert_throws sub{ conn_call($hc, qw(clonegame 72)) }, 404;
};

# TestServerHostHostGame::testListGame: GAMELIST and related.
#    This test is similar to c2systest/host/04_listgame.
test 'host/50_game/list', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Prepare: create a bunch of games in different states
    # - 1: public/joining
    assert_equals conn_call($hc, 'newgame'), 1;
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));

    # - 2: unlisted/joining
    assert_equals conn_call($hc, 'newgame'), 2;
    conn_call($hc, qw(gamesettype 2 unlisted));
    conn_call($hc, qw(gamesetstate 2 joining));

    # - 3: public/preparing
    assert_equals conn_call($hc, 'newgame'), 3;
    conn_call($hc, qw(gamesettype 3 public));
    conn_call($hc, qw(gamesetstate 3 preparing));

    # - 4: private/preparing
    assert_equals conn_call($hc, 'newgame'), 4;
    conn_call($hc, qw(gamesettype 4 private));
    conn_call($hc, qw(gamesetstate 4 preparing));
    conn_call($hc, qw(gamesetowner 4 u));

    # Test
    # - admin
    # - admin
    assert_set_equals conn_call($hc, qw(gamelist id)),                           [1,2,3,4];
    assert_set_equals conn_call($hc, qw(gamelist id type public)),               [1,3];
    assert_set_equals conn_call($hc, qw(gamelist id state joining)),             [1,2];
    assert_set_equals conn_call($hc, qw(gamelist id state joining type public)), [1];
    assert_set_equals conn_call($hc, qw(gamelist id state running type public)), [];
    assert_set_equals conn_call($hc, qw(gamelist id state preparing)),           [3,4];

    # - user "u"
    conn_call($hc, qw(user u));
    assert_set_equals conn_call($hc, qw(gamelist id state preparing)),           [4];

    # - user "z"
    conn_call($hc, qw(user z));
    assert_set_equals conn_call($hc, qw(gamelist id state preparing)),           [];

    # While we are at it, test getTotals
    my %t = conn_call_list($hc, qw(gametotals));
    assert_equals $t{joining}, 1;         # only public!
    assert_equals $t{running}, 0;
    assert_equals $t{finished}, 0;

    # Likewise, test getOwner
    conn_call($hc, 'user', 'z');
    assert_equals conn_call($hc, qw(gamegetowner 1)), '';
    assert_throws sub{ conn_call($hc, qw(gamegetowner 4)) }, 403;

    conn_call($hc, 'user', '');
    assert_equals conn_call($hc, qw(gamegetowner 4)), 'u';

    conn_call($hc, 'user', 'u');
    assert_equals conn_call($hc, qw(gamegetowner 4)), 'u';
};

# TestServerHostHostGame::testGameInfo: GAMESTAT
test 'host/50_game/stat', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Prepare: create two games
    assert_equals conn_call($hc, qw(newgame)), 1;
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(gamesetname 1 One));

    assert_equals conn_call($hc, qw(newgame)), 2;
    conn_call($hc, qw(gamesettype 2 public));
    conn_call($hc, qw(gamesetstate 2 joining));
    conn_call($hc, qw(gamesetname 2 Two));

    # Query single game
    my %i = conn_call_list($hc, qw(gamestat 2));
    assert_equals $i{id}, 2;
    assert_equals $i{state}, 'joining';
    assert_equals $i{type}, 'public';
    assert_equals $i{name}, 'Two';

    # Query list
    my @is = conn_call_list_of_hash($hc, qw(gamelist));
    assert_equals scalar(@is), 2;
    assert_equals $is[0]{id}, 1;
    assert_equals $is[0]{name}, 'One';
    assert_equals $is[1]{id}, 2;
    assert_equals $is[1]{name}, 'Two';

    # Query list, no match
    assert !conn_call_list($hc, qw(gamelist state running));

    # Query single, error case
    assert_throws sub{ conn_call($hc, qw(gamestat 3)) }, 404;
};

# TestServerHostHostGame::testSetConfigSimple: GAMESET
test 'host/50_game/set', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');

    # Create a game
    assert_equals conn_call($hc, qw(newgame)), 1;

    # Set config
    conn_call($hc, 'gameset', 1, description => 'The Game', rankDisable => 1);

    # Verify
    assert_equals conn_call($db, qw(hget game:1:settings description)), 'The Game';
    assert_equals conn_call($db, qw(hget game:1:settings rankDisable)), 1;

    # Read back
    assert_equals conn_call($hc, qw(gameget 1 description)), 'The Game';
    assert_equals conn_call($hc, qw(gameget 1 rankDisable)), 1;

    # Read back, complex
    my @r = conn_call_list($hc, qw(gamemget 1 rankDisable endChanged description));
    assert_equals scalar(@r), 3;
    assert_equals $r[0], 1;
    assert !$r[1];                       # undef in -classic, empty in -ng.
    assert_equals $r[2], 'The Game';
};

# TestServerHostHostGame::testSetConfigTool: GAMESET for tool config.
#    Must implicitly set the configChanged flag.
test 'host/50_game/set/tool', sub {
    my $setup = shift;
    prepare($setup);
    add_default_tools($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create game
    assert_equals conn_call($hc, qw(newgame)), 1;
    assert_equals conn_call($hc, qw(gameget 1 host)), 'H';

    # Set config
    conn_call($hc, qw(gameset 1 host P));

    # Read back
    assert_equals conn_call($hc, qw(gameget 1 host)), 'P';
    assert_equals conn_call($hc, qw(gameget 1 configChanged)), '1';
};

# TestServerHostHostGame::testSetConfigToolError: GAMESET with bad tool config.
#    Must fail the setting completely.
test 'host/50_game/set/toolerror', sub {
    my $setup = shift;
    prepare($setup);
    add_default_tools($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create game
    assert_equals conn_call($hc, qw(newgame)), 1;

    # Set config
    assert_throws sub{ conn_call($hc, qw(gameset 1 rankDisable 1 host zzz)) }, qr{400|412};  # ng: 400, classic: 412

    # Read back
    assert_equals conn_call($hc, qw(gameget 1 host)), 'H';
    assert_equals conn_call($hc, qw(gameget 1 rankDisable)), '';
};

# TestServerHostHostGame::testSetConfigEnd: GAMESET with end config.
#    Must set the endChanged flag.
test 'host/50_game/set/end', sub {
    my $setup = shift;
    prepare($setup);
    add_default_tools($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create game
    assert_equals conn_call($hc, qw(newgame)), 1;

    # Set config
    conn_call($hc, qw(gameset 1 endCondition turn endTurn 80));

    # Read back
    assert_equals conn_call($hc, qw(gameget 1 endCondition)), 'turn';
    assert_equals conn_call($hc, qw(gameget 1 endTurn)), 80;
    assert_equals conn_call($hc, qw(gameget 1 endChanged)), 1;
};

# TestServerHostHostGame::testSetConfigEndHide: GAMESET with end config and endChanged flag.
#    Must NOT set the endChanged flag because it was specified in the transaction.
test 'host/50_game/set/endhide', sub {
    my $setup = shift;
    prepare($setup);
    add_default_tools($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Create game
    assert_equals conn_call($hc, qw(newgame)), 1;

    # Set config
    conn_call($hc, qw(gameset 1 endCondition turn endChanged 0 endTurn 80));

    # Read back
    assert_equals conn_call($hc, qw(gameget 1 endCondition)), 'turn';
    assert_equals conn_call($hc, qw(gameget 1 endTurn)), 80;
    assert_equals conn_call($hc, qw(gameget 1 endChanged)), 0;
};

# TestServerHostHostGame::testTools: GAMETOOLADD/RM/LS
test 'host/50_game/tools', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');

    # Add some tools
    conn_call($db, 'hmset', 'prog:tool:prog:x1', kind => 'xk', description => 'text one');
    conn_call($db, 'hmset', 'prog:tool:prog:x2', kind => 'xk', description => 'text two');
    conn_call($db, 'hmset', 'prog:tool:prog:y',  kind => 'yk', description => 'text three');
    conn_call($db, 'sadd', 'prog:tool:list', $_) foreach qw(x1 x2 y);

    # Create a game
    assert_equals conn_call($hc, qw(newgame)), 1;

    # List tools; must be none
    assert !conn_call_list($hc, qw(gamelstools 1));

    # Add tools
    assert_equals conn_call($hc, qw(gameaddtool 1 x1)), 1;
    assert_equals conn_call($hc, qw(gameaddtool 1 y)), 1;

    # List tools; must be both
    # FIXME: the list is not guaranteed to be sorted - should it?
    my @list = sort {$a->{id} cmp $b->{id}} conn_call_list_of_hash($hc, qw(gamelstools 1));
    assert_equals scalar(@list), 2;
    assert_equals $list[0]{id}, 'x1';
    assert_equals $list[0]{description}, 'text one';
    assert_equals $list[0]{kind}, 'xk';
    assert_equals $list[1]{id}, 'y';
    assert_equals $list[1]{description}, 'text three';
    assert_equals $list[1]{kind}, 'yk';

    # Add tool x2; replaces x1
    assert_equals conn_call($hc, qw(gameaddtool 1 x2)), 1;

    # List tools; must be x2 and y
    @list = sort {$a->{id} cmp $b->{id}} conn_call_list_of_hash($hc, qw(gamelstools 1));
    assert_equals scalar(@list), 2;
    assert_equals $list[0]{id}, 'x2';
    assert_equals $list[0]{description}, 'text two';
    assert_equals $list[0]{kind}, 'xk';
    assert_equals $list[1]{id}, 'y';

    # Remove y
    assert_equals conn_call($hc, qw(gamermtool 1 y)), 1;
    @list = conn_call_list_of_hash($hc, qw(gamelstools 1));
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{id}, 'x2';

    # Remove non-present
    assert_equals conn_call($hc, qw(gamermtool 1 y)), 0;

    # Remove non-existant
    assert_throws sub{ conn_call($hc, qw(gamermtool 1 qq)) }, 404;

    # Add already present
    assert_equals conn_call($hc, qw(gameaddtool 1 x2)), 0;

    # Add non-existant
    assert_throws sub{ conn_call($hc, qw(gameaddtool 1 q)) }, 404;
};

# TestServerHostHostGame::testUpdateAdmin: GAMEUPDATE.
#    The command doesn't do anything particular interesting, just verify that it's accepted.
test 'host/50_game/update', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');

    # Existing game
    assert_equals conn_call($hc, qw(newgame)), 1;
    conn_call($hc, qw(gameupdate 1));

    # Nonexisting game
    assert_throws sub{ conn_call($hc, qw(gameupdate 99999)) }, 404;
};

# TestServerHostHostGame::testUpdateUser: GAMEUPDATE as user.
test 'host/50_game/update/user', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(user x));

    assert_equals conn_call($hc, qw(newgame)), 1;
    assert_throws sub{ conn_call($hc, qw(gameupdate 1)) }, 403;
};

# TestServerHostHostGame::testVictoryCondition: GAMEGETVC
test 'host/50_game/victory', sub {
    my $setup = shift;
    prepare($setup);

    # Create a game
    my $hc = setup_connect_app($setup, 'host');
    assert_equals conn_call($hc, qw(newgame)), 1;

    # Configure
    conn_call($hc, qw(gameset 1 endCondition turn endTurn 50 endProbability 3));

    # Verify
    my %vc = conn_call_list($hc, qw(gamegetvc 1));
    assert_equals $vc{endCondition}, 'turn';
    assert_equals $vc{endTurn}, 50;
    assert_equals $vc{endProbability}, 3;
};

# TestServerHostHostGame::testListUserGames: GAMELIST with user filters
test 'host/50_game/listuser', sub {
    my $setup = shift;
    prepare($setup);

    # Create a game
    my $gid = add_complex_game($setup);
    assert_equals $gid, 1;

    # Tests
    my $hc = setup_connect_app($setup, 'host');

    # User a, b, c: must list game
    assert_set_equals conn_call($hc, qw(gamelist user a id)), [$gid];
    assert_set_equals conn_call($hc, qw(gamelist user b id)), [$gid];
    assert_set_equals conn_call($hc, qw(gamelist user c id)), [$gid];

    # User z: must NOT list game (owner, but not player)
    assert_set_equals conn_call($hc, qw(gamelist user z id)), [];

    # Filters
    assert_set_equals conn_call($hc, qw(gamelist user a id type public)), [$gid];
    assert_set_equals conn_call($hc, qw(gamelist user a id type public state running)), [];
    assert_set_equals conn_call($hc, qw(gamelist user a id state running)), [];
};


sub prepare {
    my $setup = shift;
    setup_add_host($setup, '-nocron');
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

sub add_default_tools {
    my $setup = shift;
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(hset prog:host:prog:H kind host));
    conn_call($db, qw(hset prog:host:prog:P kind host));
    conn_call($db, qw(hset prog:master:prog:M kind master));
    conn_call($db, qw(hset prog:sl:prog:S kind shiplist));
    conn_call($db, qw(set prog:host:default H));
    conn_call($db, qw(set prog:master:default M));
    conn_call($db, qw(set prog:sl:default S));
    conn_call($db, qw(sadd prog:host:list H));
    conn_call($db, qw(sadd prog:host:list P));
    conn_call($db, qw(sadd prog:master:list M));
    conn_call($db, qw(sadd prog:dl:list S));
}

sub add_complex_game {
    my $setup = shift;

    # Add pseudo-users (just to survive a "user exists" check)
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd user:all), $_) foreach qw(a b c d e f z);

    # Add game
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gamesetstate', $gid, 'joining');
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetowner', $gid, 'z');

    # Add users
    conn_call($hc, 'playerjoin', $gid, 1, 'a');
    conn_call($hc, 'playerjoin', $gid, 2, 'b');
    conn_call($hc, 'playersubst', $gid, 2, 'c');
    conn_call($hc, 'playerjoin', $gid, 3, 'd');
    conn_call($hc, 'playersubst', $gid, 3, 'e');
    conn_call($hc, 'playersubst', $gid, 3, 'f');

    $gid;
}
