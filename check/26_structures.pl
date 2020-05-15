#!/usr/bin/perl -w
#
#  c2check: planetary structure tests
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Check sale of structures.
# A: prepare game directory that sells structures
# E: check fails
test 'check/26_structures/sell/mines', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{1}{mines} = 10; $_[0]{1}{money} = 60; });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{1}{mines} = 20; $_[0]{1}{money} = 10; });
    ct_run_must_fail($setup, $dir, "10 Mines have been sold. This is not permitted.");
};
test 'check/26_structures/sell/factories', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{1}{factories} = 10; $_[0]{1}{money} = 50; });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{1}{factories} = 20; $_[0]{1}{money} = 10; });
    ct_run_must_fail($setup, $dir, "10 Factories have been sold. This is not permitted.");
};
test 'check/26_structures/sell/defense', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{1}{defense} = 10; $_[0]{1}{money} = 120; });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{1}{defense} = 20; $_[0]{1}{money} = 10; });
    ct_run_must_fail($setup, $dir, "10 Defense Posts have been sold. This is not permitted.");
};
test 'check/26_structures/sell/base', sub {
    # Note that this actually is not possible because host always spits out the "buildbase" property as zero.
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub 
                 {
                     $_[0]{1}{buildbase} = 0;
                     $_[0]{1}{money} = 1000;
                     $_[0]{1}{t} = 1402;
                     $_[0]{1}{d} = 1120;
                     $_[0]{1}{m} = 1340;
                 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub
                 {
                     $_[0]{1}{buildbase} = 1;
                     $_[0]{1}{money} = 100;
                     $_[0]{1}{t} = 1000;
                     $_[0]{1}{d} = 1000;
                     $_[0]{1}{m} = 1000;
                 });
    ct_run_must_fail($setup, $dir, "1 Starbase have been sold. This is not permitted.");
};

# Check buying structures over limit
# A: prepare game directory that buys structures over limit
# E: check fails
test 'check/26_structures/buy/mines', sub {
    my $setup = shift;
    my @test_cases = ([ 10,  10, 1],
                      [ 10,  11, 0],
                      [200, 201, 0],
                      [201, 201, 1],
                      [600, 220, 1],
                      [600, 221, 0]);
    foreach my $c (@test_cases) {
        my ($colos, $units, $success) = @$c;
        trace_process("Trying $units");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{1}{clans} = $colos; $_[0]{1}{mines} = $units; $_[0]{1}{sup} = 0; });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{1}{clans} = $colos; $_[0]{1}{mines} = 0;      $_[0]{1}{sup} = 5*$units; });
        if ($success) {
            ct_run_must_succeed($setup, $dir);
        } else {
            ct_run_must_fail($setup, $dir, "Too many Mines have been built.");
        }
    }
};
test 'check/26_structures/buy/factories', sub {
    my $setup = shift;
    my @test_cases = ([ 10,  10, 1],
                      [ 10,  11, 0],
                      [100, 101, 0],
                      [101, 101, 1],
                      [500, 120, 1],
                      [500, 121, 0]);
    foreach my $c (@test_cases) {
        my ($colos, $units, $success) = @$c;
        trace_process("Trying $units");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{1}{clans} = $colos; $_[0]{1}{factories} = $units; $_[0]{1}{sup} = 0; });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{1}{clans} = $colos; $_[0]{1}{factories} = 0;      $_[0]{1}{sup} = 4*$units; });
        if ($success) {
            ct_run_must_succeed($setup, $dir);
        } else {
            ct_run_must_fail($setup, $dir, "Too many Factories have been built.");
        }
    }
};
test 'check/26_structures/buy/defense', sub {
    my $setup = shift;
    my @test_cases = ([ 10,  10, 1],
                      [ 10,  11, 0],
                      [ 50,  51, 0],
                      [ 51,  51, 1],
                      [150,  60, 1],
                      [150,  61, 0]);
    foreach my $c (@test_cases) {
        my ($colos, $units, $success) = @$c;
        trace_process("Trying $units");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{1}{clans} = $colos; $_[0]{1}{defense} = $units; $_[0]{1}{sup} = 0; });
        ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{1}{clans} = $colos; $_[0]{1}{defense} = 0;      $_[0]{1}{sup} = 11*$units; });
        if ($success) {
            ct_run_must_succeed($setup, $dir);
        } else {
            ct_run_must_fail($setup, $dir, "Too many Defense Posts have been built.");
        }
    }
};
