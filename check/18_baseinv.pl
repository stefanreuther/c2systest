#!/usr/bin/perl -w
#
#  c2check: base invariant errors
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test wrong owner.
# A: Prepare universe where base is not owned by same player as planet.
# E: Must succeed but give a warning.
test 'check/18_baseinv/owner/wrong', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{baseowner} = 1 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{baseowner} = 1 });
    ct_run_must_succeed_with_message($setup, $dir, "WARNING: Starbase 63 is not owned by the same player as the planet.");
};

# Test change of base owner.
# A: prepare universe where a base owner changes
# E: Must fail with a specific error.
test 'check/18_baseinv/owner/change', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{baseowner} = 1 });
    ct_run_must_fail($setup, $dir, "INVALID: Starbase 63: Base Owner was modified.");
};

# Test base owner out of range.
# A: prepare universe where a base owner is out of range
# E: Must fail with a specific error.
test 'check/18_baseinv/owner/range', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{baseowner} = 12 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{baseowner} = 12 });
    ct_run_must_fail($setup, $dir, "RANGE: Starbase 63: Base Owner out of allowed range.");
};

# Test build-base flag set on planet that has a base.
# A: prepare universe where a base is built on a planet that already has one.
# E: Must fail with a specific error.
test 'check/18_baseinv/build', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{6}{buildbase} = 1 });
    ct_run_must_fail($setup, $dir, "RANGE: Planet 63: Base Build Order out of allowed range.");
};
