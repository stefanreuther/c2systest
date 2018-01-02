#!/usr/bin/perl -w
#
#  Host: HostPlayer
#
#  Synced with TestServerHostHostPlayer, 20170925
#
use strict;
use c2systest;
use c2service;

# TestServerHostHostPlayer::testJoin: PLAYERJOIN.
# Tests just command acceptance; we cannot test scheduler behaviour here.
test 'host/50_player/join', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);

    # Create a game
    my $gid = add_game($setup, 'public', 'joining');
    assert_equals $gid, 1;

    # Join users
    my $hc = setup_connect_app($setup, 'host');
    foreach (1 .. 11) {
        conn_call($hc, 'playerjoin', $gid, $_, "u$_");
    }

    # Resign
    conn_call($hc, 'playerresign', $gid, 7, 'u7');
};

# TestServerHostHostPlayer::testJoinFail: PLAYERJOIN failure cases, admin access.
test 'host/50_player/join/fail', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    my $hc = setup_connect_app($setup, 'host');

    # Error: game does not exist
    assert_throws sub{ conn_call($hc, qw(playerjoin 77 1 u1)) }, 404;

    # Error: slot does not exist
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 99 u1)) }, 409;

    # Error: user does not exist
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 1 zz)) }, 404;

    # Error: slot already taken
    conn_call($hc, qw(playerjoin 1 3 u3));
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 3 u4)) }, 409;

    # Not an error: you are already on this game - not detected if we're admin
    conn_call($hc, qw(playerjoin 1 4 u3));
};

# TestServerHostHostPlayer::testJoinFailUser: PLAYERJOIN failure cases, user access.
test 'host/50_player/join/fail/user', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));

    # Set user context for all subsequent commands
    conn_call($hc, qw(user u3));

    # Error: game does not exist
    assert_throws sub{ conn_call($hc, qw(playerjoin 77 1 u3)) }, 404;

    # Error: slot does not exist
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 99 u3)) }, 409;

    # Error: slot already taken
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 3 u3)) }, 409;

    # Error: you cannot join someone else
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 3 u4)) }, 403;

    # Error: you are already on this game
    conn_call($hc, qw(playerjoin 1 1 u3));
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 2 u3)) }, 403;
};

# TestServerHostHostPlayer::testResign: PLAYERRESIGN
# Tests just command acceptance; we cannot test scheduler behaviour here.
test 'host/50_player/resign', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join some users
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playerjoin 1 2 u2));
    conn_call($hc, qw(playerjoin 1 3 u3));
    conn_call($hc, qw(playersubst 1 3 u4));

    # Resign: no notification
    conn_call($hc, qw(playerresign 1 3 u4));
    conn_call($hc, qw(playerresign 1 3 u3));
};

# TestServerHostHostPlayer::testResignCombo: PLAYERRESIGN combos.
#    Resigning all replacements resigns further replacements.
test 'host/50_player/resign/combo', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join 4 users to one slot
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playersubst 1 1 u3));
    conn_call($hc, qw(playersubst 1 1 u4));
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 4;

    # Resign u3
    conn_call($hc, qw(playerresign 1 1 u3));

    # u1,u2 remain
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2'];
};

# TestServerHostHostPlayer::testResignCombo2: PLAYERRESIGN combo 2.
test 'host/50_player/resign/combo2', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join 4 users to one slot
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playersubst 1 1 u3));
    conn_call($hc, qw(playersubst 1 1 u4));
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 4;

    # Resign u1
    conn_call($hc, qw(playerresign 1 1 u1));

    # Nobody remains
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 0;
};

# TestServerHostHostPlayer::testResignComboPerm: PLAYERRESIGN
test 'host/50_player/resign/perms', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join 5 users to one slot
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playersubst 1 1 u3));
    conn_call($hc, qw(playersubst 1 1 u4));
    conn_call($hc, qw(playersubst 1 1 u5));
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 5;

    # Set user u3
    conn_call($hc, qw(user u3));

    # Cannot resign primary or previous replacement, or users who are not playing
    assert_throws sub{ conn_call($hc, qw(playerresign 1 1 u1)) }, 403;
    assert_throws sub{ conn_call($hc, qw(playerresign 1 1 u2)) }, 403;
    assert_throws sub{ conn_call($hc, qw(playerresign 1 1 u6)) }, 403;

    # Can resign u5
    conn_call($hc, qw(playerresign 1 1 u5));
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 4;

    # Can resign ourselves and our replacement
    conn_call($hc, qw(playerresign 1 1 u3));

    # u1,u2 remain
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 2;
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2'];
};

# TestServerHostHostPlayer::testSubstitute: PLAYERSUBST
test 'host/50_player/subst', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join 5 users to one slot
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playersubst 1 1 u3));
    conn_call($hc, qw(playersubst 1 1 u4));
    conn_call($hc, qw(playersubst 1 1 u5));
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 5;

    # Substitute u3: this will drop everyone after u3
    conn_call($hc, qw(playersubst 1 1 u3));
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2', 'u3'];

    # Substitute u4: will add
    conn_call($hc, qw(playersubst 1 1 u4));
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2', 'u3', 'u4'];
};

# TestServerHostHostPlayer::testSubstituteUser: PLAYERSUBST, user
test 'host/50_player/subst/user', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join 5 users to one slot
    my $hc = setup_connect_app($setup, 'host');
    my $db = setup_connect_app($setup, 'db');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playersubst 1 1 u3));
    conn_call($hc, qw(playersubst 1 1 u4));
    conn_call($hc, qw(playersubst 1 1 u5));
    assert_equals conn_call($db, qw(llen game:1:player:1:users)), 5;

    # Set as user u3
    conn_call($hc, qw(user u3));

    # Try to substitute u2: not possible because they are before us
    assert_throws sub{ conn_call($hc, qw(playersubst 1 1 u2)) }, 403;

    # Try to substitute u4: ok, kicks u5
    conn_call($hc, qw(playersubst 1 1 u4));
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2', 'u3', 'u4'];

    # Substitute u9: ok, replaces u5 by u9
    conn_call($hc, qw(playersubst 1 1 u9));
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2', 'u3', 'u9'];

    # Substitute u3: kicks everyone up to u3
    conn_call($hc, qw(playersubst 1 1 u3));
    assert_list_equals conn_call($db, qw(lrange game:1:player:1:users 0 -1)), ['u1', 'u2', 'u3'];
};

# TestServerHostHostPlayer::testSubstituteEmpty: PLAYERSUBST, empty slot
#    This must fail.
test 'host/50_player/subst/empty', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Substitute into empty slot, fails
    my $hc = setup_connect_app($setup, 'host');
    assert_throws sub{ conn_call($hc, qw(playersubst 1 2 u2)) }, 412;
};

# TestServerHostHostPlayer::testAddPlayer: PLAYERADD.
test 'host/50_player/add', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'private', 'joining');

    # Two connections
    my $user = setup_connect_app($setup, 'host');
    my $root = setup_connect_app($setup, 'host');
    conn_call($user, qw(user u3));

    # Game access initially not allowed to user
    assert_throws sub{ conn_call($user, qw(gamestat 1)) }, 403;

    # Player cannot add themselves
    assert_throws sub{ conn_call($user, qw(playeradd 1 u3)) }, 403;

    # Add player to that game using admin permissions
    conn_call($root, qw(playeradd 1 u3));

    # Game access now works
    conn_call($user, qw(gamestat 1));
};

# TestServerHostHostPlayer::testSlotInfo: PLAYERLS, PLAYERSTAT
test 'host/50_player/stat', sub {
    my $setup = shift;
    prepare($setup);
    c2service::setup_hostfile_add_defaults($setup);
    add_users($setup);
    add_game($setup, 'private', 'joining');

    # Join some users
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playerjoin 1 7 u3));
    conn_call($hc, qw(playerjoin 1 11 u4));

    # Get information about a slot
    my %i = conn_call_list($hc, qw(playerstat 1 1));
    assert_equals $i{long}, 'Long Race 1';
    assert_equals $i{short}, 'Short Race 1';
    assert_equals $i{adj}, 'Adj 1';
    assert_equals scalar(@{$i{users}}), 2;
    assert_equals $i{users}[0], 'u1';
    assert_equals $i{users}[1], 'u2';
    assert_equals $i{editable}, 2;
    assert_equals $i{joinable}, 0;

    %i = conn_call_list($hc, qw(playerstat 1 7));
    assert_equals scalar(@{$i{users}}), 1;
    assert_equals $i{users}[0], 'u3';

    %i = conn_call_list($hc, qw(playerstat 1 9));
    assert_equals scalar(@{$i{users}}), 0;
    assert_equals $i{joinable}, 1;

    # List
    # FIXME: test all=true vs all=false!
    my %list = conn_call_list_of_hash($hc, qw(playerls 1));
    assert_equals $list{1}{short}, 'Short Race 1';
    assert_equals $list{9}{short}, 'Short Race 9';
};

# TestServerHostHostPlayer::testDirectory: PLAYERSETDIR/PLAYERGETDIR
test 'host/50_player/dir', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Create a home directory
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u4home u4));

    # Join a user
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));

    # Directory name initially unset
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), '';

    # Set directory
    conn_call($hc, qw(playersetdir 1 u4 u4home/x/y));

    # Query
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), 'u4home/x/y';

    # Verify
    my %info = conn_call_list($ufc, qw(stat u4home/x/y));
    assert_equals $info{type}, 'dir';
    assert_equals conn_call($ufc, qw(propget u4home/x/y game)), 1;
};

# TestServerHostHostPlayer::testDirectoryErrorFilePerm: directories, permission error case.
#    Setting the directory to a non-writable area must fail, and not change the game config.
test 'host/50_player/dir/perms', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Join a user
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));

    # Set directory.
    # Fails because we didn't create the parent directory.
    assert_throws sub{ conn_call($hc, qw(playersetdir 1 u4 u4home/x/y)) }, 403;

    # Query. Must still be empty.
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), '';
};

# TestServerHostHostPlayer::testDirectoryErrorUserPerm: directories, user error case.
#    Setting the directory for a different user is refused.
test 'host/50_player/dir/user', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Create a home directories
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u4home u4));
    conn_call($ufc, qw(mkdiras u1home u1));

    # Join a user
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));

    # Set directory as user u1
    conn_call($hc, qw(user u1));
    assert_throws sub{ conn_call($hc, qw(playersetdir 1 u4 u1home/x/y)) }, 403;
    assert_throws sub{ conn_call($hc, qw(playersetdir 1 u4 u4home/x/y)) }, 403;

    # Query
    assert_throws sub{ conn_call($hc, qw(playergetdir 1 u4)) }, 403;

    # Query as admin, it didn't change
    conn_call($hc, 'user', '');
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), '';
};

# TestServerHostHostPlayer::testDirectoryErrorGame: directories, subscription error case.
#    Setting the directory fails if you're not subscribed.
test 'host/50_player/dir/sub', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Create a home directory
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u4home u4));

    # Set directory, fails because we're not subscribed
    my $hc = setup_connect_app($setup, 'host');
    assert_throws sub{ conn_call($hc, qw(playersetdir 1 u4 u4home/x/y)) }, 403;

    # Query, fails because we're not subscribed
    assert_throws sub{ conn_call($hc, qw(playergetdir 1 u4)) }, 403;
};

# TestServerHostHostPlayer::testDirectoryErrorChange: directories, error during directory change.
test 'host/50_player/dir/change', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Create a home directory
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u4home u4));

    # Create a game and join a user
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));

    # Set directory, works
    conn_call($hc, qw(playersetdir 1 u4 u4home/x/y));
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), 'u4home/x/y';
    assert_equals conn_call($ufc, qw(propget u4home/x/y game)), 1;

    # Move to different place, fails
    assert_throws sub{ conn_call($hc, qw(playersetdir 1 u4 elsewhere/y)) }, 403;

    # Configuration unchanged
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), 'u4home/x/y';
};

# TestServerHostHostPlayer::testDirectoryConflict: directories, conflict case.
#    A game must refuse pointing its directory at the same place as another game.
test 'host/50_player/dir/conflict', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);

    # Home
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u4home u4));

    # Create two games and join a user
    my $gid1 = add_game($setup, 'public', 'joining');
    my $gid2 = add_game($setup, 'public', 'joining');
    assert_equals $gid1, 1;
    assert_equals $gid2, 2;

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));
    conn_call($hc, qw(playerjoin 2 4 u4));

    # Set directory, works
    conn_call($hc, qw(playersetdir 1 u4 u4home/x/y));
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), 'u4home/x/y';
    assert_equals conn_call($ufc, qw(propget u4home/x/y game)), 1;

    # Set other game's directory the same as this one, must fail and leave the configuration unchanged
    assert_throws sub{ conn_call($hc, qw(playersetdir 2 u4 u4home/x/y)) }, 601;
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), 'u4home/x/y';
    assert_equals conn_call($hc, qw(playergetdir 2 u4)), '';
    assert_equals conn_call($ufc, qw(propget u4home/x/y game)), 1;
};

# TestServerHostHostPlayer::testDirectoryMove: directories, move case.
test 'host/50_player/dir/move', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Create a home directory
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u4home u4));

    # Create a game and join a user
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 3 u4));

    # Set directory
    conn_call($hc, qw(playersetdir 1 u4 u4home/x/y));
    assert_equals conn_call($hc, qw(playergetdir 1 u4)), 'u4home/x/y';
    assert_equals conn_call($ufc, qw(propget u4home/x/y game)), 1;

    # Move
    conn_call($hc, qw(playersetdir 1 u4 u4home/a/b));
    assert_equals conn_call($ufc, qw(propget u4home/a/b game)), 1;
    assert_equals conn_call($ufc, qw(propget u4home/x/y game)), 0;
};

# TestServerHostHostPlayer::testCheckFile: PLAYERCHECKFILE
test 'host/50_player/checkfile', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'joining');

    # Create a home directory
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, qw(mkdiras u3home u3));

    # Create a game and join two users
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playerjoin 1 3 u3));
    conn_call($hc, qw(playersetdir 1 u3 u3home/x));

    # Check with no directory name: Stale for 1 because they have not set a directory
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 xyplan.dat)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 xyplan.dat)), 'refuse';
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 fizz.bin)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 fizz.bin)), 'allow';

    # Check with wrong directory name
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 xyplan.dat dir a)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 xyplan.dat dir a)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 fizz.bin dir a)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 fizz.bin dir a)), 'stale';

    # Check with correct directory name
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 xyplan.dat dir u3home/x)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 xyplan.dat dir u3home/x)), 'refuse';
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 fizz.bin dir u3home/x)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 fizz.bin dir u3home/x)), 'allow';

    # Turn files: must refuse turns that don't match the player
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 player1.trn)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u1 player3.trn)), 'stale';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 player1.trn)), 'refuse';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 player3.trn)), 'trn';
    assert_equals conn_call($hc, qw(playercheckfile 1 u3 player99.trn)), 'refuse';
};

# TestServerHostHostPlayer::testGameState: join/resign/substitute in wrong game state.
test 'host/50_player/state', sub {
    my $setup = shift;
    prepare($setup);
    add_users($setup);
    add_game($setup, 'public', 'preparing');

    # Operations fail
    my $hc = setup_connect_app($setup, 'host');
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 1 u1)) }, 412;
    assert_throws sub{ conn_call($hc, qw(playersubst 1 1 u2)) }, 412;
    assert_throws sub{ conn_call($hc, qw(playerresign 1 1 u2)) }, 412;

    # Make it joining, add users, finish
    conn_call($hc, qw(gamesetstate 1 joining));
    conn_call($hc, qw(playerjoin 1 1 u1));
    conn_call($hc, qw(playersubst 1 1 u2));
    conn_call($hc, qw(playerjoin 1 2 u3));
    conn_call($hc, qw(playerjoin 1 3 u4));
    conn_call($hc, qw(gamesetstate 1 finished));

    # Operations still fail
    assert_throws sub{ conn_call($hc, qw(playerjoin 1 4 u1)) }, 412;
    assert_throws sub{ conn_call($hc, qw(playersubst 1 3 u2)) }, 412;
    assert_throws sub{ conn_call($hc, qw(playerresign 1 1 u2)) }, 412;
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

sub add_users {
    my $setup = shift;
    my $db = setup_connect_app($setup, 'db');
    foreach (1 .. 20) {
        conn_call($db, 'sadd', 'user:all', "u$_");
        conn_call($db, 'set', "uid:u$_", "u$_");
    }
}
