#!/usr/bin/perl -w
#
#  Host: test installation of player files
#

use strict;
use c2systest;
use c2service;

# Test joining: normal case.
# A player joins another slot in a game (normally only possible via replacements).
# This updates their game directory with the new results.
test 'host/13_install/join', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Let player 'a' join. This must upload files.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/a/games/my-play-dir));
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/player2.rst)), 'rst 2';
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/spec.dat)), 'spec';

    # Join another slot. Must upload more files.
    conn_call($hc, qw(playerjoin 1 9 1001));
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/player9.rst)), 'rst 9';

    # Verify other properties.
    assert_equals conn_call($ufc, qw(propget u/a/games/my-play-dir game)), 1;
    assert_equals conn_call($ufc, qw(propget u/a/games/my-play-dir nofilewarning)), 1;
};

# Test resigning: normal case.
# A player resigns a slot in a game. This updates their game directory.
test 'host/13_install/resign', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Let player 'a' join as two races. This must upload files.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/a/games/my-play-dir));
    conn_call($hc, qw(playerjoin 1 9 1001));
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/player9.rst)), 'rst 9';
    assert_equals conn_call($ufc, qw(propget u/a/games/my-play-dir game)), 1;

    # Resign. File must be removed, but properties still set
    conn_call($hc, qw(playerresign 1 9 1001));
    assert_throws sub{ conn_call($ufc, qw(get u/a/games/my-play-dir/player9.rst)) }, 404;
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/player2.rst)), 'rst 2';
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/spec.dat)), 'spec';
    assert_equals conn_call($ufc, qw(propget u/a/games/my-play-dir game)), 1;

    # Resign finally. This will leave the files, but drop the association,
    conn_call($hc, qw(playerresign 1 2 1001));
    assert_equals conn_call($ufc, qw(propget u/a/games/my-play-dir game)), 0;
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/spec.dat)), 'spec';
};

# Test turn submission. The turn files are distributed to players.
test 'host/13_install/turn', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Let player 'a' join and 'b' replace.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/a/games/my-play-dir));
    conn_call($hc, qw(playersubst 1 2 1002));
    conn_call($hc, qw(playersetdir 1 1002 u/b/hh));

    # Submit a turn file.
    my $trn = c2service::vp_make_turn(2, conn_call($hc, qw(gameget 1 timestamp)));
    conn_call($hc, 'trn', $trn);

    # Both must have received that file.
    assert_equals conn_call($ufc, qw(get u/b/hh/player2.trn)), $trn;
    assert_equals conn_call($ufc, qw(get u/a/games/my-play-dir/player2.trn)), $trn;
};

# Test retroactive turn submission. If a turn file was uploaded first, it must end up in game directories.
test 'host/13_install/turn2', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Let player 'a' join and upload a turn.
    my $trn = c2service::vp_make_turn(2, conn_call($hc, qw(gameget 1 timestamp)));
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, 'trn', $trn);

    # Set directory. It must receive the turn file.
    conn_call($hc, qw(playersetdir 1 1001 u/a/x));
    assert_equals conn_call($ufc, qw(get u/a/x/player2.trn)), $trn;
};


# Test error case: setting a not-permitted directory
test 'host/13_install/set_error', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Let player 'a' join.
    conn_call($hc, qw(playerjoin 1 2 1001));

    # We are using unrestricted permissions to talk to host, but the actual installation should be done with user permissions and thus fail.
    assert_throws sub { conn_call($hc, qw(playersetdir 1 1001 u/b/dir)) }, 403;

    # Consequently, there shouldn't be a directory.
    assert_throws sub { conn_call($ufc, qw(stat u/b/dir)) }, 404;

    # Directory should not be set in DB
    assert_equals conn_call($hc, qw(playergetdir 1 1001)), '';
};

# Test error case: permissions retroactively removed, then joining [#349]
test 'host/13_install/join_error', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Make a directory where 'a' has permissions
    conn_call($ufc, qw(mkdir u/b/dir));
    conn_call($ufc, qw(setperm u/b/dir 1001 rwl));

    # Let player 'a' join.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/b/dir));

    # Remove permissions
    conn_call($ufc, qw(setperm u/b/dir 1001 0));

    # Join another race. Must succeed despite being unable to install files.
    conn_call($hc, qw(playerjoin 1 7 1001));

    # Verify that join actually worked.
    my %stat = @{ conn_call($hc, qw(playerstat 1 7)) };
    assert_equals join(',', @{$stat{users}}), '1001';
};

# Test error case: permissions retroactively removed, then joining [#349]
test 'host/13_install/join_error2', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');

    # Make a directory where 'a' has permissions
    conn_call($ufc, qw(mkdir u/b/dir));
    conn_call($ufc, qw(setperm u/b/dir 1001 rwl));

    # Let player 'a' join.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/b/dir));

    # Player 'b' also joins and sets a directory.
    # This performs operations on the filer in context of b (1002).
    # If c2host messes up user permissions, it might carry over this user context for the following resign.
    conn_call($hc, qw(playerjoin 1 5 1002));
    conn_call($hc, qw(playersetdir 1 1002 u/b/elsewhere));

    # Remove permissions and join another.
    conn_call($ufc, qw(setperm u/b/dir 1001 0));
    conn_call($hc, qw(playerjoin 1 7 1001));

    # Verify that join actually worked.
    my %stat = @{ conn_call($hc, qw(playerstat 1 7)) };
    assert_equals join(',', @{$stat{users}}), '1001';

    # File must not have been places
    assert_throws sub{ conn_call($ufc, qw(stat u/b/dir/player7.rst)) }, 404;
};

# Test error case: permissions retroactively removed, then resigning
test 'host/13_install/resign_error', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');
    my $dbc = setup_connect_app($setup, 'db');

    # Make a directory where 'a' has permissions
    conn_call($ufc, qw(mkdir u/b/dir));
    conn_call($ufc, qw(setperm u/b/dir 1001 rwl));

    # Let player 'a' join.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/b/dir));
    conn_call($hc, qw(playerjoin 1 7 1001));
    assert_equals conn_call($dbc, qw(hget game:1:users 1001)), 2;

    # Remove permissions
    conn_call($ufc, qw(setperm u/b/dir 1001 0));

    # Resign
    conn_call($hc, qw(playerresign 1 7 1001));
    conn_call($hc, qw(playerresign 1 2 1001));

    # Verify that resign actually worked.
    assert_equals conn_call($dbc, qw(hget game:1:users 1001)), 0;

    # Could not retract the game property, though!
    assert_equals conn_call($ufc, qw(propget u/b/dir game)), 1;
};

# Test error case: permissions retroactively removed, then resigning
test 'host/13_install/resign_error2', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');
    my $dbc = setup_connect_app($setup, 'db');

    # Make a directory where 'a' has permissions
    conn_call($ufc, qw(mkdir u/b/dir));
    conn_call($ufc, qw(setperm u/b/dir 1001 rwl));

    # Let player 'a' join.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/b/dir));

    # Player 'b' also joins and sets a directory.
    # This performs operations on the filer in context of b (1002).
    # If c2host messes up user permissions, it might carry over this user context for the following resign.
    conn_call($hc, qw(playerjoin 1 5 1002));
    conn_call($hc, qw(playersetdir 1 1002 u/b/elsewhere));

    # Remove permissions and resign. Resign 2
    conn_call($ufc, qw(setperm u/b/dir 1001 0));
    conn_call($hc, qw(playerresign 1 2 1001));

    # Resign cannot retract the game property
    assert_equals conn_call($ufc, qw(propget u/b/dir game)), 1;
};

# Test error case: permissions retroactively removed, then submitting a turn
test 'host/13_install/trn_error', sub {
    my $setup = shift;
    prepare($setup);
    my $hc = setup_connect_app($setup, 'host');
    my $ufc = setup_connect_app($setup, 'file');
    my $dbc = setup_connect_app($setup, 'db');

    # Make a directory where 'a' has permissions
    conn_call($ufc, qw(mkdir u/b/dir));
    conn_call($ufc, qw(setperm u/b/dir 1001 rwl));

    # Let player 'a' join.
    conn_call($hc, qw(playerjoin 1 2 1001));
    conn_call($hc, qw(playersetdir 1 1001 u/b/dir));
    conn_call($hc, qw(playersubst 1 2 1002));
    conn_call($hc, qw(playersetdir 1 1002 u/b/dir2));

    # Remove permissions
    conn_call($ufc, qw(setperm u/b/dir 1001 0));

    # Submit a turn file.
    my $trn = c2service::vp_make_turn(2, conn_call($hc, qw(gameget 1 timestamp)));
    conn_call($hc, 'trn', $trn);

    # File must have arrived in b's directory, but not in a's
    assert_equals conn_call($ufc, qw(get u/b/dir2/player2.trn)), $trn;
    assert_throws sub { conn_call($ufc, qw(get u/b/dir/player2.trn)) }, 404;
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_host($setup);
    setup_add_talk($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_start_wait($setup);
    c2service::setup_db_init($setup);
    c2service::setup_add_user($setup, 'a');
    c2service::setup_add_user($setup, 'b');
    c2service::setup_hostfile_add_defaults($setup);

    my $hfc = setup_connect_app($setup, 'hostfile');
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');

    # Dummy scripts
    # Note that c2host-classic expects bin/checkturn.sh to move the turn from in/new/ to in/.
    conn_call($hfc, 'put', 'bin/runhost.sh', 'true');
    conn_call($hfc, 'put', 'bin/checkturn.sh', 'mv "$1/in/new/player$2.trn" "$1/in/player$2.trn"');

    # Dummy tools
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    # Create a game
    my $gid = conn_call($hc, 'newgame');
    my $timestamp = '2222-11-2211:22:33';
    assert_equals $gid, 1;
    conn_call($hc, 'gameset', $gid, 'turn', 10);
    conn_call($hc, 'gameset', $gid, 'hostHasRun', 1);
    conn_call($hc, 'gameset', $gid, 'lastHostTime', 1);         # required to prevent host from running immediately
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gameset', $gid, 'timestamp', $timestamp);   # FIXME: should this be magic and automatically update the index?
    conn_call($dbc, 'set', "game:bytime:$timestamp", $gid);

    # Manual state transition because we don't want the scheduler to kick in.
    # conn_call($hc, 'gamesetstate', $gid, 'running');
    my $old_state = conn_call($dbc, 'getset', "game:$gid:state", 'running');
    conn_call($dbc, 'smove', "game:state:preparing", "game:state:running", $gid);
    conn_call($dbc, 'smove', "game:pubstate:preparing", "game:pubstate:running", $gid);

    # Dummy files
    my $dir = conn_call($hc, 'gamegetdir', $gid);
    foreach (1..11) {
        conn_call($hfc, 'put', "$dir/out/$_/player$_.rst", "rst $_");
    }
    conn_call($hfc, 'put', "$dir/out/all/spec.dat", "spec");
}
