#!/usr/bin/perl -w
#
#  c2check: test checksum errors
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $control_spec = {
    mode => 'fixed',
    count => 1500,
    pattern => 'V',
    fields => ['x']
};

# Test missing control file.
# A: Prepare directory without control file.
# E: Invocation with '-c' must fail, error must reference missing file.
test 'check/14_control/missing', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/contrl7.dat";
    ct_run_must_fail($setup, $dir, 'FATAL: Unable to find a checksum (control) file', '-c');
};

# Test missing control file.
# E: Prepare directory without control file.
# A: No error. Missing file is ok if checksum validation is not requested.
test 'check/14_control/missingok', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/contrl7.dat";
    ct_run_must_succeed($setup, $dir);
};

# Test short control file.
# A: Truncate control file.
# E: Invocation with '-c' must fail with specific error message.
test 'check/14_control/short', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/contrl7.dat", substr(file_content("$dir/contrl7.dat"), 0, 1000));
    ct_run_must_fail($setup, $dir, 'SYNTAX: contrl7.dat is too short', '-c');
};

# Test short control file.
# A: Prepare directory with 500-ship control file but ship Id >501.
# E: Invocation with '-c' must produce a warning, but succeed.
test 'check/14_control/ship501', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{id} = 501 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{id} = 501 });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Checksum for ship 501 is not contained in file contrl7.dat', '-c');
};

# Test checksum mismatch.
#   Ship 156
#   Planet 195
#   Base 140
# A: Modify control file
# E: Invocation with '-c' must produce a warning, but succeed.
test 'check/14_control/mismatch/ship', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/contrl7.dat", $control_spec, sub { shift->{156}{x}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Ship 156 checksum mismatch', '-c');
};
test 'check/14_control/mismatch/planet', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/contrl7.dat", $control_spec, sub { shift->{195+500}{x}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Planet 195 checksum mismatch', '-c');
};
test 'check/14_control/mismatch/base', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/contrl7.dat", $control_spec, sub { shift->{140+1000}{x}++ });
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: Starbase 140 checksum mismatch', '-c');
};
