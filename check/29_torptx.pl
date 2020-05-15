#!/usr/bin/perl -w
#
#  c2check: test torpedo transfer
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# We have the following location:
#   Base 63 {1}
#   Planet 63 {6}
#   Ship 67 {4}    // Mark 7 Torps
#   Ship 158 {7}   // Mark 8 Torps

# Test moving torpedoes between mismatching ships.
# A: prepare directory that transfers torpedoes between mismatching ships
# E: Check must fail with at least one balance error.
test 'check/29_torptx/mismatch_ship', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 10;
                     $_[0]{7}{ammo} = 0;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 0;
                     $_[0]{7}{ammo} = 10;
                 });
    ct_run_must_fail($setup, $dir, 'BALANCE:');
};

# Test moving torpedoes between matching ships.
# A: prepare directory
# E: Check must succeed
test 'check/29_torptx/match_ship', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 10;
                     $_[0]{7}{ammo} = 0;
                     $_[0]{4}{torp} = $_[0]{7}{torp} = 3;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 0;
                     $_[0]{7}{ammo} = 10;
                     $_[0]{4}{torp} = $_[0]{7}{torp} = 3;
                 });
    ct_run_must_succeed($setup, $dir);
};

# Test moving torpedoes between base and ships, wrong type.
# A: prepare directory
# E: Check must fail with at least a balance error.
test 'check/29_torptx/mismatch_base', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 10;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 12;
                 });
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub
                 {
                     $_[0]{1}{t10} = 20;
                 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub
                 {
                     $_[0]{1}{t10} = 18;
                 });
    ct_run_must_fail($setup, $dir, 'BALANCE:');
};

# Test moving torpedoes between base and ships.
# A: prepare directory
# E: Check must succeed.
test 'check/29_torptx/match_base', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 10;
                     $_[0]{7}{ammo} = 10;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 12;
                     $_[0]{7}{ammo} = 8;
                 });
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub
                 {
                     $_[0]{1}{torptech} = 1;
                     $_[0]{1}{t9} = 22;
                     $_[0]{1}{t10} = 18;
                 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub
                 {
                     $_[0]{1}{torptech} = 1;
                     $_[0]{1}{t9} = 20;
                     $_[0]{1}{t10} = 20;
                 });
    ct_run_must_succeed($setup, $dir);
};

# We have the following location:
#   Planet 159 {12}
#   Ship 18 {2}    // Mark 5 Torps

# Test building torpedoes on a planet that has no base.
# A: prepare directory
# E: Check must fail with at least a BALANCE error.
test 'check/29_torptx/no_base', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{2}{ammo} = 10;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{2}{ammo} = 5;
                 });
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub
                 {
                     $_[0]{12}{t} = 10;
                     $_[0]{12}{d} = 10;
                     $_[0]{12}{m} = 10;
                     $_[0]{12}{money} = 10;
                 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub
                 {
                     $_[0]{12}{t} = 15;
                     $_[0]{12}{d} = 15;
                     $_[0]{12}{m} = 15;
                     $_[0]{12}{money} = 165;
                 });
    ct_run_must_fail($setup, $dir, 'BALANCE:');
};

# Test building torpedoes on a planet that has a base.
# A: prepare directory
# E: Check must succeed
test 'check/29_torptx/has_base', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 10;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{4}{ammo} = 5;
                 });
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub
                 {
                     $_[0]{6}{t} = 10;
                     $_[0]{6}{d} = 10;
                     $_[0]{6}{m} = 10;
                     $_[0]{6}{money} = 10;
                 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub
                 {
                     $_[0]{6}{t} = 15;
                     $_[0]{6}{d} = 15;
                     $_[0]{6}{m} = 15;
                     $_[0]{6}{money} = 190;
                 });
    ct_run_must_succeed($setup, $dir);
};

# We have the following location:
#   Ship 420 {17}    // Mark 7 Torps

# Test building torpedoes on a ship in space.
# A: prepare directory
# E: check must fail.
test 'check/29_torptx/in_space', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub
                 {
                     $_[0]{17}{ammo} = 1;
                     $_[0]{17}{t} = 0;
                     $_[0]{17}{d} = 0;
                     $_[0]{17}{m} = 0;
                     $_[0]{17}{money} = 0;
                     $_[0]{17}{clans} = 0;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub
                 {
                     $_[0]{17}{ammo} = 0;
                     $_[0]{17}{t} = 1;
                     $_[0]{17}{d} = 1;
                     $_[0]{17}{m} = 1;
                     $_[0]{17}{money} = 36;
                     $_[0]{17}{clans} = 0;
                 });
    ct_run_must_fail($setup, $dir, 'Resources appeared in free space');
};
