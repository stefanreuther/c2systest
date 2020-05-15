#!/usr/bin/perl -w
#
#  c2check: genX.dat tests
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $desc = {
    fields => [qw(timestamp scoreblob player password shipsum pdatasum bdatasum newpwflag newpw turn timecheck)],
    pattern => 'A18A88vA21V3vA10vv',
    mode => 'auto'
};

# Test missing gen.dat file
# A: remove file
# E: error result
test 'check/08_gen/missing', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/gen7.dat";
    ct_run_must_fail($setup, $dir, 'gen7.dat');
};

# Test truncated gen.dat file
# A: truncate file
# E: error result
test 'check/08_gen/trunc', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/gen7.dat", substr(file_content("$dir/gen7.dat"), 0, 100));
    ct_run_must_fail($setup, $dir, 'gen7.dat');
};

# Test wrong player
# A: change file owner
# E: error result
test 'check/08_gen/player', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{player} = 3 });
    ct_run_must_fail($setup, $dir, 'INVALID: gen7.dat belongs to player 3, not 7');
};

# Test wrong new-password flag
# A: change new-password flag to invalid value
# E: error result
test 'check/08_gen/newpw/wrong', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{newpwflag} = 17 });
    ct_run_must_fail($setup, $dir, 'INVALID: password flag has invalid value 17');
};

# Test correct new-password flag
# A: change new-password flag to valid value
# E: success result
test 'check/08_gen/newpw/ok1', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{newpwflag} = 13 });
    ct_run_must_succeed($setup, $dir);
};

# Test correct new-password flag
# A: change new-password flag to valid value
# E: success result
test 'check/08_gen/newpw/ok2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{newpwflag} = 0 });
    ct_run_must_succeed($setup, $dir);
};

# Test wrong turn number
# A: change turn number to invalid value
# E: error result
test 'check/08_gen/turn', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{turn} = -1 });
    ct_run_must_fail($setup, $dir, 'INVALID: turn number has invalid value -1');
};

# Test wrong timestamp
# A: change timestamp to invalid format
# E: error result
test 'check/08_gen/timestamp', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{timestamp} = 'Hi Mom' });
    ct_run_must_fail($setup, $dir, 'INVALID: time stamp has an invalid format');
};

# Test wrong timestamp checksum
# A: change timestamp checksum to invalid format
# E: success result (with warning when '-c' is used)
test 'check/08_gen/timecheck', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{timecheck}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: gen7.dat timestamp checksum mismatch', '-c');
    ct_run_must_succeed($setup, $dir);
};

# Test wrong ship total checksum
# A: change ship checksum to invalid format
# E: success result (with warning when '-c' is used)
test 'check/08_gen/shipcheck', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{shipsum}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Ship totals checksum mismatch', '-c');
    ct_run_must_succeed($setup, $dir);
};

# Test wrong planet total checksum
# A: change planet checksum to invalid format
# E: success result (with warning when '-c' is used)
test 'check/08_gen/planetcheck', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{pdatasum}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Planet totals checksum mismatch', '-c');
    ct_run_must_succeed($setup, $dir);
};

# Test wrong base total checksum
# A: change base checksum to invalid format
# E: success result (with warning when '-c' is used)
test 'check/08_gen/basecheck', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/gen7.dat", $desc, sub { shift->{1}{bdatasum}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Starbase totals checksum mismatch', '-c');
    ct_run_must_succeed($setup, $dir);
};
