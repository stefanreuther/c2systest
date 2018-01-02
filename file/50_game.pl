#!/usr/bin/perl -w
#
#  File: FileBase
#
#  Synced with TestServerFileFileGame, 20170923.
#  Fails with c2file-classic.
#
use strict;
use c2systest;
use c2service;

# TestServerFileFileGame::testEmpty: Test operation on empty directories and other errors.
test 'file/50_game/empty', sub {
    my $fc = prepare(@_);

    # Attempt to access root (root cannot be named)
    assert_throws sub{ conn_call($fc, 'statgame', '') }, 400;
    assert_throws sub{ conn_call($fc, 'lsgame', '') }, 400;
    assert_throws sub{ conn_call($fc, 'statreg', '') }, 400;
    assert_throws sub{ conn_call($fc, 'lsreg', '') }, 400;

    # Create an empty directory and attempt to read it
    conn_call($fc, qw(mkdir x));
    assert_throws sub{ conn_call($fc, 'statgame', 'x') }, 404;
    assert_equals scalar(conn_call_list($fc, 'lsgame', 'x')), 0;
    assert_throws sub{ conn_call($fc, 'statreg', 'x') }, 404;
    assert_equals scalar(conn_call_list($fc, 'lsreg', 'x')), 0;

    assert_throws sub{ conn_call($fc, 'lsgame', 'x/y/z') }, 404;
    assert_throws sub{ conn_call($fc, 'lsreg', 'x/y/z') }, 404;

    # Missing permissions
    conn_call($fc, qw(user 1001));
    assert_throws sub{ conn_call($fc, 'lsgame', 'x') }, 403;
    assert_throws sub{ conn_call($fc, 'statgame', 'x') }, 403;
    assert_throws sub{ conn_call($fc, 'lsreg', 'x') }, 403;
    assert_throws sub{ conn_call($fc, 'statreg', 'x') }, 403;

    assert_throws sub{ conn_call($fc, 'lsgame', 'x/y/z') }, 403;
    assert_throws sub{ conn_call($fc, 'lsreg', 'x/y/z') }, 403;
};

# TestServerFileFileGame::testReg: Test operation on directories that contain keys.
test 'file/50_game/reg', sub {
    # Prepare the test bench
    my $fc = prepare(@_);
    conn_call($fc, 'mkdirhier', 'a/b/c');
    conn_call($fc, 'mkdirhier', 'a/b/d');
    conn_call($fc, 'put', 'a/b/c/fizz.bin', image_default_reg_key());
    conn_call($fc, 'put', 'a/b/fizz.bin', image_default_reg_key());
    conn_call($fc, 'setperm', 'a/b', '1001', 'r');
    conn_call($fc, 'setperm', 'a/b/c', '1002', 'r');

    # Single stat
    my %ki = conn_call_list($fc, 'statreg', 'a/b');
    assert_equals $ki{path}, 'a/b';
    assert_equals $ki{file}, 'a/b/fizz.bin';
    assert_equals $ki{reg}, 0;

    # List
    my @kis = conn_call_list($fc, 'lsreg', 'a/b');
    assert_equals scalar(@kis), 2;

    %ki = @{$kis[0]};
    assert_equals $ki{file}, 'a/b/fizz.bin';
    %ki = @{$kis[1]};
    assert_equals $ki{file}, 'a/b/c/fizz.bin';

    # Stat as user 1001
    conn_call($fc, qw(user 1001));
    %ki = conn_call_list($fc, 'statreg', 'a/b');
    assert_equals $ki{path}, 'a/b';
    assert_equals $ki{file}, 'a/b/fizz.bin';
    assert_equals $ki{reg}, 0;

    assert_throws sub{ conn_call_list($fc, 'statreg', 'a/b/c') }, 403;

    # List as user 1001 (gets only available content)
    @kis = conn_call_list($fc, 'lsreg', 'a/b');
    assert_equals scalar(@kis), 1;
    %ki = @{$kis[0]};
    assert_equals $ki{file}, 'a/b/fizz.bin';

    # List as user 1002 (gets only available content)
    conn_call($fc, qw(user 1002));

    assert_throws sub{ conn_call_list($fc, 'lsreg', 'a/b') }, 403;

    @kis = conn_call_list($fc, 'lsreg', 'a/b/c');
    assert_equals scalar(@kis), 1;
    %ki = @{$kis[0]};
    assert_equals $ki{file}, 'a/b/c/fizz.bin';
};

# TestServerFileFileGame::testGame
test 'file/50_game/game', sub {
    my $fc = prepare(@_);

    conn_call($fc, 'mkdirhier', 'a/b/c');
    conn_call($fc, 'mkdirhier', 'a/b/d');
    conn_call($fc, 'put', 'a/b/c/player7.rst', image_result_file(7));
    conn_call($fc, 'put', 'a/b/race.nm', c2service::vp_race_names());
    conn_call($fc, 'put', 'a/b/player7.rst', image_result_file(7));
    conn_call($fc, 'setperm', 'a/b', '1001', 'r');
    conn_call($fc, 'setperm', 'a/b/c', '1002', 'r');

    # Single stat
    my %gi = conn_call_list($fc, 'statgame', 'a/b');
    assert_equals $gi{path}, 'a/b';
    assert_equals scalar(@{$gi{races}}), 2;         # key+value
    assert_equals $gi{races}[0], 7;
    assert_equals $gi{races}[1], 'Long Race 7';

    # List
    my @gis = conn_call_list($fc, 'lsgame', 'a/b');
    assert_equals scalar(@gis), 2;

    %gi = @{$gis[0]};
    assert_equals $gi{path}, 'a/b';
    assert_equals scalar(@{$gi{races}}), 2;         # key+value
    assert_equals $gi{races}[0], 7;
    assert_equals $gi{races}[1], 'Long Race 7';

    %gi = @{$gis[1]};
    assert_equals $gi{path}, 'a/b/c';
    assert_equals scalar(@{$gi{races}}), 2;         # key+value
    assert_equals $gi{races}[0], 7;
    # c2file uses the installed default race names (share/specs/race.nm) if none are given
    assert_equals $gi{races}[1], 'The Crystal Confederation';

    # Stat as user 1001
    conn_call($fc, qw(user 1001));
    %gi = conn_call_list($fc, 'statgame', 'a/b');
    assert_equals $gi{path}, 'a/b';
    assert_equals scalar(@{$gi{races}}), 2;         # key+value
    assert_equals $gi{races}[0], 7;

    assert_throws sub{ conn_call($fc, 'statgame', 'a/b/c') }, 403;

    # List as user 1001 (gets only available content)
    @gis = conn_call_list($fc, 'lsgame', 'a/b');
    assert_equals scalar(@gis), 1;
    %gi = @{$gis[0]};
    assert_equals $gi{path}, 'a/b';

    # List as user 1002 (gets only available content)
    conn_call($fc, qw(user 1002));

    assert_throws sub{ conn_call($fc, 'lsgame', 'a/b') }, 403;

    @gis = conn_call_list($fc, 'lsgame', 'a/b/c');
    assert_equals scalar(@gis), 1;
    %gi = @{$gis[0]};
    assert_equals $gi{path}, 'a/b/c';
};

# TestServerFileFileGame::testGameProps
test 'file/50_game/props', sub {
    my $fc = prepare(@_);

    # Prepare the test bench
    conn_call($fc, 'mkdir', 'a');
    conn_call($fc, 'put', 'a/player7.rst', image_result_file(7));
    conn_call($fc, 'propset', 'a', 'game', '42');
    conn_call($fc, 'propset', 'a', 'finished', '1');
    conn_call($fc, 'propset', 'a', 'name', 'Forty Two');
    conn_call($fc, 'propset', 'a', 'hosttime', '998877');
    conn_call($fc, 'put', 'a/xyplan.dat', '');

    conn_call($fc, 'mkdir', 'b');
    conn_call($fc, 'put', 'b/player7.rst', image_result_file(7));
    conn_call($fc, 'propset', 'b', 'game', 'what?');
    conn_call($fc, 'propset', 'b', 'finished', 'yep');

    # Query a
    my %gi = conn_call_list($fc, 'statgame', 'a');
    assert_equals $gi{path}, 'a';
    assert_equals scalar(@{$gi{races}}), 2;     # key+value
    assert_equals $gi{name}, 'Forty Two';
    assert_equals $gi{finished}, 1;
    assert_equals $gi{hosttime}, 998877;
    assert !grep {$_ eq 'xyplan.dat'} @{$gi{missing}};

    # Query b (which has bogus properties)
    %gi = conn_call_list($fc, 'statgame', 'b');
    assert_equals $gi{path}, 'b';
    assert_equals scalar(@{$gi{races}}), 2;     # key+value
    assert_equals $gi{name}, '';
    assert_equals $gi{game}, 0;                 # fails in -classic which gives values verbatim
    assert_equals $gi{finished}, 0;
    assert_equals $gi{hosttime}, 0;
    assert grep {$_ eq 'xyplan.dat'} @{$gi{missing}};
};


sub prepare {
    my $setup = shift;
    setup_add_userfile($setup);
    setup_start_wait($setup);

    setup_connect_app($setup, 'file');
}

sub image_default_reg_key {
    join('', map {chr hex}
         qw(9b 02 00 00 83 06 00 00 ee 04 00 00 9b 02 00 00 83 06 00 00 ee 04 00 00 9b 02 00 00 83 06 00 00 ee 04 00 00
            9b 02 00 00 83 06 00 00 ee 04 00 00 9b 02 00 00 83 06 00 00 ee 04 00 00 9b 02 00 00 83 06 00 00 ee 04 00 00
            9b 02 00 00 83 06 00 00 ee 04 00 00 9b 02 00 00 83 06 00 00 ee 04 00 00 57 7c 04 00 0e 6e 02 00 86 1d 00 00
            9b 02 00 00 83 06 00 00 ee 04 00 00 9b 02 00 00 83 06 00 00 ee 04 00 00 00 00 00 00 5e 04 00 00 36 07 00 00
            e7 09 00 00 80 06 00 00 50 14 00 00 e8 20 00 00 7b 22 00 00 b0 2c 00 00 29 2e 00 00 e8 3a 00 00 3d 40 00 00
            80 13 00 00 eb 4b 00 00 f0 49 00 00 e3 49 00 00 a0 5c 00 00 31 57 00 00 c6 6c 00 00 97 5d 00 00 c8 73 00 00
            b5 6b 00 00 c0 23 00 00 60 25 00 00 00 27 00 00 a0 28 00 00 5e 04 00 00 42 0a 00 00 5e 11 00 00 5c 17 00 00
            a9 1a 00 00 d2 21 00 00 1a 27 00 00 00 0d 00 00 4f 17 00 00 5c 17 00 00 d0 1a 00 00 40 1d 00 00 20 15 00 00
            c0 16 00 00 60 18 00 00 00 1a 00 00 a0 1b 00 00 40 1d 00 00 e0 1e 00 00 80 20 00 00 20 22 00 00 c0 23 00 00
            60 25 00 00 00 27 00 00 a0 28 00 00 fb d5 07 00));
}

sub image_result_file {
    my $player = shift;
    my $gen = join('',
                   "11-22-333344:55:66",        # time
                   "\0" x 88,                   # scores
                   pack("v", $player),          # player
                   "x" x 20,                    # password [not valid]
                   "\0" x 12,                   # checksums
                   "\5\0",                      # turn 5
                   "\x9e\x03");                 # timestamp sum
    my @content = ("\0\0",          # ships
                   "\0\0",          # VCs
                   "\0\0",          # planets
                   "\0\0",          # bases
                   "\0\0",          # messages
                   "\0" x 4000,     # shipxy
                   $gen,            # gen
                   "\0\0");         # vcrs
    my $pos = 1 + 8*4;
    my $result = "";
    foreach (@content) {
        $result .= pack "V", $pos;
        $pos += length($_);
    }
    join ("", $result, @content);
}
